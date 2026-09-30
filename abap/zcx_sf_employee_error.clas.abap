"! Exception raised by the SuccessFactors employee query provider.
"! CX_RAP_QUERY_PROVIDER is abstract and cannot be instantiated directly,
"! so this concrete subclass is used to report errors to the RAP framework.
CLASS zcx_sf_employee_error DEFINITION
  PUBLIC
  INHERITING FROM cx_rap_query_provider
  FINAL
  CREATE PUBLIC.
ENDCLASS.


CLASS zcx_sf_employee_error IMPLEMENTATION.
ENDCLASS.
