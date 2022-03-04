include: "dq_constants.view.lkml"
include: "dq_ude.view.lkml"
include: "dq_ssvf.view.lkml"
include: "dq_rhy.view.lkml"
include: "dq_hopwa.view.lkml"
include: "dq_path.view.lkml"
include: "/views/clarity/client_program_demographics/screen_*.view.lkml"
view: dq_client_program_demographics {

  sql_table_name: client_program_demographics ;;
  extends: [
    screen_master,
    dq_ssvf,
    dq_rhy,
    dq_hopwa,
    dq_ude,
    dq_path,
    entry_screen,
    status_update_screen,
    last_screen,
    followup_screen
  ]

  set: dq_client_program_demographics_drills {
    fields: [data_quality.id, dq_client_programs.id]
  }

  dimension: ref_client {
    label: "Personal ID"
    view_label: "Enrollments"
    type: number
    value_format_name: id
    hidden: yes
    sql: ${TABLE}.ref_client ;;
  }
}