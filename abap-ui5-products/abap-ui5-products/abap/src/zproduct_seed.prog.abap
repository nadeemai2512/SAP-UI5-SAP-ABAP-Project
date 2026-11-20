REPORT zproduct_seed.

START-OF-SELECTION.

  SELECT COUNT(*) FROM zproduct INTO @DATA(lv_count).
  IF lv_count > 0.
    WRITE: / |Table ZPRODUCT already contains { lv_count } products - nothing inserted.|.
    RETURN.
  ENDIF.

  DATA lt_rows TYPE STANDARD TABLE OF zproduct WITH DEFAULT KEY.

  lt_rows = VALUE #(
    ( name = 'Laptop Pro 15'      description = '15 inch business laptop'    category = 'Computers'   price = '1499.00' currency = 'EUR' stock = 25 )
    ( name = 'Wireless Mouse'     description = 'Ergonomic bluetooth mouse'  category = 'Accessories' price = '29.90'   currency = 'EUR' stock = 150 )
    ( name = 'USB-C Dock'         description = '10-in-1 docking station'    category = 'Accessories' price = '89.00'   currency = 'EUR' stock = 4 )
    ( name = '27 inch Monitor'    description = '4K IPS display'             category = 'Displays'    price = '399.00'  currency = 'EUR' stock = 0 )
    ( name = 'Mechanical Keyboard' description = 'Hot-swappable keyboard'    category = 'Accessories' price = '119.50'  currency = 'EUR' stock = 60 ) ).

  LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
    TRY.
        <ls_row>-mandt      = sy-mandt.
        <ls_row>-product_id = cl_system_uuid=>create_uuid_c32_static( ).
      CATCH cx_uuid_error INTO DATA(lx_uuid).
        WRITE: / lx_uuid->get_text( ).
        RETURN.
    ENDTRY.
  ENDLOOP.

  INSERT zproduct FROM TABLE @lt_rows.
  IF sy-subrc = 0.
    COMMIT WORK.
    WRITE: / |{ lines( lt_rows ) } sample products inserted into ZPRODUCT.|.
  ELSE.
    ROLLBACK WORK.
    WRITE: / 'Insert failed.'.
  ENDIF.
