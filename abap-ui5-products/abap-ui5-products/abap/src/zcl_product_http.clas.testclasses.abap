CLASS ltcl_validate DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS valid_product  FOR TESTING.
    METHODS missing_name   FOR TESTING.
    METHODS negative_price FOR TESTING.
    METHODS negative_stock FOR TESTING.
ENDCLASS.


CLASS ltcl_validate IMPLEMENTATION.

  METHOD valid_product.
    DATA(lv_message) = zcl_product_http=>validate(
      VALUE zcl_product_http=>ty_product( name = 'Mouse' price = '10.00' stock = 5 ) ).
    cl_abap_unit_assert=>assert_initial( lv_message ).
  ENDMETHOD.

  METHOD missing_name.
    DATA(lv_message) = zcl_product_http=>validate(
      VALUE zcl_product_http=>ty_product( price = '10.00' stock = 5 ) ).
    cl_abap_unit_assert=>assert_equals( act = lv_message exp = 'Name is required' ).
  ENDMETHOD.

  METHOD negative_price.
    DATA(lv_message) = zcl_product_http=>validate(
      VALUE zcl_product_http=>ty_product( name = 'Mouse' price = '-1.00' stock = 5 ) ).
    cl_abap_unit_assert=>assert_equals( act = lv_message exp = 'Price must not be negative' ).
  ENDMETHOD.

  METHOD negative_stock.
    DATA(lv_message) = zcl_product_http=>validate(
      VALUE zcl_product_http=>ty_product( name = 'Mouse' price = '10.00' stock = -3 ) ).
    cl_abap_unit_assert=>assert_equals( act = lv_message exp = 'Stock must not be negative' ).
  ENDMETHOD.

ENDCLASS.
