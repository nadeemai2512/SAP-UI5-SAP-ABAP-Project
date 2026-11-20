"! Products REST/JSON service for the ICF (SICF) node /sap/zproducts
"!
"! GET    /sap/zproducts                       list all products
"! GET    /sap/zproducts?id=<id>               read one product
"! POST   /sap/zproducts                       create (JSON body)
"! PUT    /sap/zproducts?id=<id>               update (JSON body)
"! DELETE /sap/zproducts?id=<id>               delete
"! POST   /sap/zproducts?id=<id>&action=restock&amount=<n>   increase stock
CLASS zcl_product_http DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_extension.

    TYPES:
      BEGIN OF ty_product,
        product_id  TYPE zproduct-product_id,
        name        TYPE zproduct-name,
        description TYPE zproduct-description,
        category    TYPE zproduct-category,
        price       TYPE zproduct-price,
        currency    TYPE zproduct-currency,
        stock       TYPE zproduct-stock,
      END OF ty_product.

    "! Business validation, returns an empty string when the product is valid
    CLASS-METHODS validate
      IMPORTING is_product        TYPE ty_product
      RETURNING VALUE(rv_message) TYPE string.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_error,
        error TYPE string,
      END OF ty_error.

    METHODS handle_get
      IMPORTING io_server TYPE REF TO if_http_server
                iv_id     TYPE zproduct-product_id.
    METHODS handle_create
      IMPORTING io_server TYPE REF TO if_http_server.
    METHODS handle_update
      IMPORTING io_server TYPE REF TO if_http_server
                iv_id     TYPE zproduct-product_id.
    METHODS handle_delete
      IMPORTING io_server TYPE REF TO if_http_server
                iv_id     TYPE zproduct-product_id.
    METHODS handle_restock
      IMPORTING io_server TYPE REF TO if_http_server
                iv_id     TYPE zproduct-product_id.
    METHODS read_body
      IMPORTING io_server         TYPE REF TO if_http_server
      RETURNING VALUE(rs_product) TYPE ty_product.
    METHODS to_json
      IMPORTING ig_data        TYPE data
      RETURNING VALUE(rv_json) TYPE string.
    METHODS send_json
      IMPORTING io_server TYPE REF TO if_http_server
                iv_json   TYPE string
                iv_code   TYPE i DEFAULT 200
                iv_reason TYPE string DEFAULT 'OK'.
    METHODS send_error
      IMPORTING io_server  TYPE REF TO if_http_server
                iv_code    TYPE i
                iv_message TYPE string.
ENDCLASS.



CLASS zcl_product_http IMPLEMENTATION.

  METHOD if_http_extension~handle_request.

    DATA(lv_method) = to_upper( server->request->get_header_field( if_http_header_fields_sap=>request_method ) ).
    DATA(lv_id)     = CONV zproduct-product_id( server->request->get_form_field( 'id' ) ).
    DATA(lv_action) = server->request->get_form_field( 'action' ).

    TRY.
        CASE lv_method.
          WHEN 'GET'.
            handle_get( io_server = server iv_id = lv_id ).

          WHEN 'POST'.
            IF lv_action = 'restock'.
              handle_restock( io_server = server iv_id = lv_id ).
            ELSE.
              handle_create( server ).
            ENDIF.

          WHEN 'PUT'.
            handle_update( io_server = server iv_id = lv_id ).

          WHEN 'DELETE'.
            handle_delete( io_server = server iv_id = lv_id ).

          WHEN OTHERS.
            send_error( io_server = server
                        iv_code = 405
                        iv_message = |Method { lv_method } not allowed| ).
        ENDCASE.
      CATCH cx_root INTO DATA(lx_root).
        ROLLBACK WORK.
        send_error( io_server = server
                    iv_code = 500
                    iv_message = lx_root->get_text( ) ).
    ENDTRY.

  ENDMETHOD.


  METHOD handle_get.

    IF iv_id IS NOT INITIAL.
      SELECT SINGLE product_id, name, description, category, price, currency, stock
        FROM zproduct
        WHERE product_id = @iv_id
        INTO @DATA(ls_product).
      IF sy-subrc <> 0.
        send_error( io_server = io_server
                    iv_code = 404
                    iv_message = |Product { iv_id } not found| ).
        RETURN.
      ENDIF.
      send_json( io_server = io_server iv_json = to_json( ls_product ) ).
    ELSE.
      SELECT product_id, name, description, category, price, currency, stock
        FROM zproduct
        ORDER BY name
        INTO TABLE @DATA(lt_products).
      send_json( io_server = io_server iv_json = to_json( lt_products ) ).
    ENDIF.

  ENDMETHOD.


  METHOD handle_create.

    DATA ls_row TYPE zproduct.

    DATA(ls_product) = read_body( io_server ).

    DATA(lv_message) = validate( ls_product ).
    IF lv_message IS NOT INITIAL.
      send_error( io_server = io_server iv_code = 400 iv_message = lv_message ).
      RETURN.
    ENDIF.

    TRY.
        ls_product-product_id = cl_system_uuid=>create_uuid_c32_static( ).
      CATCH cx_uuid_error INTO DATA(lx_uuid).
        send_error( io_server = io_server iv_code = 500 iv_message = lx_uuid->get_text( ) ).
        RETURN.
    ENDTRY.

    IF ls_product-currency IS INITIAL.
      ls_product-currency = 'EUR'.
    ENDIF.

    MOVE-CORRESPONDING ls_product TO ls_row.
    ls_row-mandt = sy-mandt.
    INSERT zproduct FROM @ls_row.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      send_error( io_server = io_server iv_code = 500 iv_message = |Insert failed| ).
      RETURN.
    ENDIF.
    COMMIT WORK.

    send_json( io_server = io_server
               iv_json   = to_json( ls_product )
               iv_code   = 201
               iv_reason = 'Created' ).

  ENDMETHOD.


  METHOD handle_update.

    DATA ls_row TYPE zproduct.

    IF iv_id IS INITIAL.
      send_error( io_server = io_server iv_code = 400 iv_message = |Parameter id is required| ).
      RETURN.
    ENDIF.

    SELECT SINGLE @abap_true FROM zproduct WHERE product_id = @iv_id INTO @DATA(lv_exists).
    IF lv_exists IS INITIAL.
      send_error( io_server = io_server iv_code = 404 iv_message = |Product { iv_id } not found| ).
      RETURN.
    ENDIF.

    DATA(ls_product) = read_body( io_server ).
    ls_product-product_id = iv_id.

    DATA(lv_message) = validate( ls_product ).
    IF lv_message IS NOT INITIAL.
      send_error( io_server = io_server iv_code = 400 iv_message = lv_message ).
      RETURN.
    ENDIF.

    MOVE-CORRESPONDING ls_product TO ls_row.
    ls_row-mandt = sy-mandt.
    UPDATE zproduct FROM @ls_row.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      send_error( io_server = io_server iv_code = 500 iv_message = |Update failed| ).
      RETURN.
    ENDIF.
    COMMIT WORK.

    send_json( io_server = io_server iv_json = to_json( ls_product ) ).

  ENDMETHOD.


  METHOD handle_delete.

    IF iv_id IS INITIAL.
      send_error( io_server = io_server iv_code = 400 iv_message = |Parameter id is required| ).
      RETURN.
    ENDIF.

    DELETE FROM zproduct WHERE product_id = @iv_id.
    IF sy-subrc <> 0.
      send_error( io_server = io_server iv_code = 404 iv_message = |Product { iv_id } not found| ).
      RETURN.
    ENDIF.
    COMMIT WORK.

    send_json( io_server = io_server
               iv_json   = ``
               iv_code   = 204
               iv_reason = 'No Content' ).

  ENDMETHOD.


  METHOD handle_restock.

    IF iv_id IS INITIAL.
      send_error( io_server = io_server iv_code = 400 iv_message = |Parameter id is required| ).
      RETURN.
    ENDIF.

    DATA(lv_amount) = CONV i( io_server->request->get_form_field( 'amount' ) ).
    IF lv_amount <= 0.
      send_error( io_server = io_server iv_code = 400 iv_message = |Amount must be greater than 0| ).
      RETURN.
    ENDIF.

    UPDATE zproduct SET stock = stock + @lv_amount WHERE product_id = @iv_id.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      send_error( io_server = io_server iv_code = 404 iv_message = |Product { iv_id } not found| ).
      RETURN.
    ENDIF.
    COMMIT WORK.

    handle_get( io_server = io_server iv_id = iv_id ).

  ENDMETHOD.


  METHOD read_body.

    DATA(lv_body) = io_server->request->get_cdata( ).
    IF lv_body IS INITIAL.
      RETURN.
    ENDIF.

    /ui2/cl_json=>deserialize(
      EXPORTING
        json        = lv_body
        pretty_name = /ui2/cl_json=>pretty_mode-camel_case
      CHANGING
        data        = rs_product ).

  ENDMETHOD.


  METHOD to_json.

    rv_json = /ui2/cl_json=>serialize(
                data        = ig_data
                pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).

  ENDMETHOD.


  METHOD send_json.

    io_server->response->set_header_field( name = 'Content-Type' value = 'application/json; charset=utf-8' ).
    io_server->response->set_header_field( name = 'Cache-Control' value = 'no-store' ).
    io_server->response->set_cdata( iv_json ).
    io_server->response->set_status( code = iv_code reason = iv_reason ).

  ENDMETHOD.


  METHOD send_error.

    DATA(ls_error) = VALUE ty_error( error = iv_message ).
    send_json( io_server = io_server
               iv_json   = to_json( ls_error )
               iv_code   = iv_code
               iv_reason = 'Error' ).

  ENDMETHOD.


  METHOD validate.

    IF is_product-name IS INITIAL.
      rv_message = 'Name is required'.
    ELSEIF is_product-price < 0.
      rv_message = 'Price must not be negative'.
    ELSEIF is_product-stock < 0.
      rv_message = 'Stock must not be negative'.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
