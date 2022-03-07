include: "dq_constants.view.lkml"
view: dq_client_program_demographics {

  dimension: ref_client {
    label: "Personal ID"
    view_label: "Enrollments"
    type: number
    value_format_name: id
    hidden: yes
    sql: ${TABLE}.ref_client ;;
  }
  
}