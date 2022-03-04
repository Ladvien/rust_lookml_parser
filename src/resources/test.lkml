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

  dimension: enrollment_id {
    type: number
    value_format_name: id
    hidden: yes
    sql: ${TABLE}.ref_program ;;
  }

  dimension: id {
    view_label: "Data Collection Stage"
    label: "Data Collection Stage Id"
    description: "Id for Data Collection Stage (@{hmis_ref_data_collection_stage}) Response."
    hidden: no
  }

  dimension: data_collection_stage {
    view_label: "Data Collection Stage"
    description: "Identifies the Data Collection Stage (@{hmis_ref_data_collection_stage}): Project Update (Status Assessment), Project Annual Assessment, Project Exit or Post Exit"
    type: string
    sql:
          CASE WHEN ${TABLE}.screen_type = ${const_project_start}
               THEN "Project Start"
               WHEN ${TABLE}.screen_type = ${const_project_update}
               THEN "Project Update"
               WHEN ${TABLE}.screen_type = ${const_project_annual}
               THEN "Project Annual Assessment"
               WHEN ${TABLE}.screen_type = ${const_project_exit}
               THEN "Project Exit"
               WHEN ${TABLE}.screen_type = ${const_post_exit}
               THEN "Post Exit"
               ELSE ${TABLE}.screen_type
          END;;
  }

  dimension_group: data_collection_stage_created_date {
    view_label: "Data Collection Stage"
    label: "Data Collection Stage Created"
    description: "The date the HUD Assessment was entered."
    timeframes: [date, week, month, year]
    type: time
    sql: ${TABLE}.added_date ;;
  }

  dimension_group: data_collection_stage_updated_date {
    view_label: "Data Collection Stage"
    label: "Data Collection Stage Updated"
    description: "The date the HUD Assessment was most recently updated."
    timeframes: [date, week, month, year]
    type: time
    sql: ${TABLE}.last_updated ;;
  }

  dimension: status_assessment_type {
    view_label: "Data Collection Stage"
    description: "Type of update assessment recorded."
    type: string
    sql:
        CASE WHEN ${TABLE}.status_screen_type = ${const_current_living_situation}
             THEN "Current Living Situation"
             WHEN ${TABLE}.status_screen_type = ${const_status_assessment}
             THEN "Status Assessment"
        ELSE ${TABLE}.status_screen_type
        END
    ;;
  }

  dimension: date_of_engagement_error {
    label: "Date of Engagement Error"
    description: "Error in @{hmis_ref_num_path_engagement_date}: Date of Engagement"
    view_label: "DQ Client Program Specific"
    allow_fill: no
    tags: ["HMIS", "4_13_1"]

    case: {
      when: {
        sql:      (${TABLE}.status_screen_type != ${const_status_assessment} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_13} = 1
              AND ((   ${dq_project_descriptor.ref_category} = ${const_emergency_shelter}
              AND ${dq_project_descriptor.tracking_method_raw} = ${const_night_by_night})
           OR ${dq_project_descriptor.ref_category} IN (${const_street_outreach}, ${const_services_only}))
          AND ${TABLE}.path_engagement_date IS NOT NULL
          AND ${TABLE}.path_engagement_date < ${enrollments.start_date};;
        label: "Engagement Date before Program Start Date"
      }
      when: {
        sql:   (${TABLE}.status_screen_type != ${const_status_assessment}  OR ${TABLE}.status_screen_type is NULL)
           AND ${dq_data_error_applies_to_program.hmis_4_13} = 1
           AND ((${dq_project_descriptor.ref_category} = ${const_emergency_shelter}
           AND ${dq_project_descriptor.tracking_method_raw} = ${const_night_by_night})
           OR ${dq_project_descriptor.ref_category} IN (${const_street_outreach}, ${const_services_only}))
          AND ${TABLE}.path_engagement_date IS NOT NULL
          AND ${TABLE}.path_engagement_date > ${enrollments.end_date};;
        label: "Engagement Date after Program End Date"
      }
      else: "None"
    }
  }

  dimension: income_from_any_source_error {
    label: "Income from Any Source Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_income_cash_is}: Income from Any Source"
    group_label: "Income Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_income_cash_is}"]

    case: {
      when: {
        sql:
                  ${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- If parent is something besides "Yes"
              AND ${TABLE}.income_cash_is != 1
              AND (
                  -- Then check each child.  If it is NULL or "No," it's all good.
                  -- Otherwise, flag an error.
                  (${TABLE}.income_earned IS NOT NULL AND ${TABLE}.income_earned != 0) OR
                  (${TABLE}.income_unemployment IS NOT NULL AND ${TABLE}.income_unemployment != 0) OR
                  (${TABLE}.income_ssi IS NOT NULL AND ${TABLE}.income_ssi != 0) OR
                  (${TABLE}.income_ssdi IS NOT NULL AND ${TABLE}.income_ssdi != 0) OR
                  (${TABLE}.income_vet_disability IS NOT NULL AND ${TABLE}.income_vet_disability != 0) OR
                  (${TABLE}.income_private_disability IS NOT NULL AND ${TABLE}.income_private_disability != 0) OR
                  (${TABLE}.income_workers_comp IS NOT NULL AND ${TABLE}.income_workers_comp != 0) OR
                  (${TABLE}.income_tanf IS NOT NULL AND ${TABLE}.income_tanf != 0) OR
                  (${TABLE}.income_ga IS NOT NULL AND ${TABLE}.income_ga != 0) OR
                  (${TABLE}.income_ga_is IS NOT NULL AND ${TABLE}.income_ga_is != 0) OR
                  (${TABLE}.income_ss_retirement IS NOT NULL AND ${TABLE}.income_ss_retirement != 0) OR
                  (${TABLE}.income_private_pension IS NOT NULL AND ${TABLE}.income_private_pension != 0) OR
                  (${TABLE}.income_childsupport IS NOT NULL AND ${TABLE}.income_childsupport != 0) OR
                  (${TABLE}.income_spousal_support IS NOT NULL AND ${TABLE}.income_spousal_support != 0)
              )
        ;;
        label: "Income from Any Source is not 'No,' but dependent fields contain value"
      }
      when: {
        sql:      ${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              AND ${TABLE}.income_cash_is IS NULL ;;
        label: "Null"
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              AND ${TABLE}.income_cash_is NOT IN (0, 1, 8, 9, 99) ;;
        label: "Invalid Income Source Selected"
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              AND ${TABLE}.income_cash_is = 8 ;;
        label: "Client doesn't know"
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              AND ${TABLE}.income_cash_is = 9 ;;
        label: "Client refused"
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              AND ${TABLE}.income_cash_is = 99 ;;
        label: "Data not collected"
      }
      else: "None"
    }
  }

  dimension: total_monthly_income_error {
    label: "Total Monthly Income Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_income_individual}: Total Monthly Income"
    group_label: "Income Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_income_individual}"]

    case: {
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              AND ${TABLE}.income_cash_is = 1
              AND (${TABLE}.income_individual IS NULL AND ${TABLE}.income_individual = 0)
              AND ${TABLE}.income_individual IS NULL ;;
        label: "Invalid Total Monthly Income selected."
      }
      else: "None"
    }
  }

  dimension: earned_income_error {
    label: "Earned Income Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_income_earned}: Earned Income"
    group_label: "Income Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", " @{hmis_ref_num_income_earned}"]

    case: {
      when: {
        sql: ${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_earned_is NOT IN (0, 1) ;;
        label: "Invalid selection for Earned Income"
      }
      when: {
        sql: ${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_earned_is = 1
              AND (${TABLE}.income_earned IS NULL AND ${TABLE}.income_earned < 1);;
        label: "Earned Income reported but invalid amount."
      }
      when: {
        sql: ${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_earned_is = 0
              AND ${TABLE}.income_earned > 0;;
        label: "No Earned Income Reported but Earned Income amount is greater than 0."
      }
      else: "None"
    }
  }

  dimension: unemployment_income_error {
    label: "Unemployment Income Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_income_unemployment}: Unemployment Income"
    group_label: "Income Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_income_unemployment}"]

    case: {
      when: {
        sql: ${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_unemployment_is NOT IN (0, 1) ;;
        label: "Invalid selection for Unemployment Income"
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_unemployment_is = 1
              AND (${TABLE}.income_unemployment IS NULL AND ${TABLE}.income_unemployment < 1);;
        label: "Unemployment Income reported but invalid amount."
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_unemployment_is = 0
              AND ${TABLE}.income_unemployment > 0;;
        label: "No Unemployment Income reported but Unemployment Income amount is greater than 0."
      }
      else: "None"
    }
  }

  dimension: ssi_income_error {
    label: "SSI Income Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_income_ssi}: SSI Income"
    group_label: "Income Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_income_ssi}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_ssi_is NOT IN (0, 1) ;;
        label: "Invalid selection for SSI Income"
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_ssi_is = 1
              AND (${TABLE}.income_ssi IS NULL AND ${TABLE}.income_ssi < 1);;
        label: "SSI Income reported but invalid amount."
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_ssi_is = 0
              AND ${TABLE}.income_ssi > 0;;
        label: "No SSI Income reported but SSI Income amount is greater than 0."
      }
      else: "None"
    }
  }

  dimension: ssdi_income_error {
    label: "SSDI Income Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_income_ssdi}: SSDI Income"
    group_label: "Income Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_income_ssdi}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_ssdi_is NOT IN (0, 1) ;;
        label: "Invalid selection for SSDI Income"
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_ssdi_is = 1
              AND (${TABLE}.income_ssdi IS NULL AND ${TABLE}.income_ssdi < 1);;
        label: "SSDI Income reported but invalid amount."
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_ssdi_is = 0
              AND ${TABLE}.income_ssdi > 0;;
        label: "No SSDI Income reported but SSDI Income amount is greater than 0."
      }
      else: "None"
    }
  }

  dimension: va_service_connected_disability_compensation_income_error {
    label: "VA Service-Connected Disability Compensation Income"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_income_vet_disability}: VA Service-Connected Disability Compensation Income"
    group_label: "Income Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_income_vet_disability}"]

    case: {
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_vet_disability_is NOT IN (0, 1) ;;
        label: "Invalid selection for Service-Connected Disability Compensation Income"
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_vet_disability_is = 1
              AND (${TABLE}.income_vet_disability IS NULL AND ${TABLE}.income_vet_disability < 1);;
        label: "Service-Connected Disability Compensation Income reported but invalid amount."
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_vet_disability_is = 0
              AND ${TABLE}.income_vet_disability > 0;;
        label: "No Service-Connected Disability Compensation Income reported but Service-Connected Disability Compensation Income amount is greater than 0."
      }
      else: "None"
    }
  }

  dimension: private_disability_insurance_income_error {
    label: "Private Disability Insurance Income Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_income_private_disability}: Private Disability Insurance Income"
    group_label: "Income Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_income_private_disability}"]

    case: {
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_private_disability_is NOT IN (0, 1) ;;
        label: "Invalid selection for Private Disability Insurance Income"
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_private_disability_is = 1
              AND (${TABLE}.income_private_disability IS NULL AND ${TABLE}.income_private_disability < 1);;
        label: "Private Disability Insurance Income reported but invalid amount."
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_private_disability_is = 0
              AND (${TABLE}.income_private_disability IS NULL AND ${TABLE}.income_private_disability > 0);;
        label: "Private Disability Insurance Income reported but Private Disability Insurance Income amount is greater than 0."
      }
      else: "None"
    }

  }

  dimension: workers_compensation_income_error {
    label: "Workers Comp Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_income_workers_comp}: Worker’s Compensation Income"
    group_label: "Income Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_income_workers_comp}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_workers_comp_is NOT IN (0, 1) ;;
        label: "Invalid selection for Worker’s Compensation Income"
      }
      when: {
        sql: ${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
            AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
            AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
            AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
            -- Child to HMIS 4.02.2
            AND ${TABLE}.income_cash_is = 1
            AND ${TABLE}.income_workers_comp_is = 1
            AND (${TABLE}.income_workers_comp IS NULL AND ${TABLE}.income_workers_comp < 1);;
        label: "Worker’s Compensation Income reported but invalid amount."
      }
      when: {
        sql:    ${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
            AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
            AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
            AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
            -- Child to HMIS 4.02.2
            AND ${TABLE}.income_cash_is = 1
            AND ${TABLE}.income_workers_comp_is = 0
            AND ${TABLE}.income_workers_comp > 0;;
        label: "Worker’s Compensation Income reported but Worker’s Compensation Income amount is greater than 0."
      }
      else: "None"
    }

  }

  dimension: temporary_assistance_for_needy_families_tanf_error {
    label: "TANF Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_income_tanf}: Temporary Assistance for Needy Families (TANF)"
    group_label: "Income Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_income_tanf}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
            AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
            AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
            AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
            -- Child to HMIS 4.02.2
            AND ${TABLE}.income_cash_is = 1
            AND ${TABLE}.income_tanf_is NOT IN (0, 1) ;;
        label: "Invalid selection for TANF Income"
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
            AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
            AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
            AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
            -- Child to HMIS 4.02.2
            AND ${TABLE}.income_cash_is = 1
            AND ${TABLE}.income_tanf_is = 1
            AND (${TABLE}.income_tanf IS NULL AND ${TABLE}.income_tanf < 1);;
        label: "TANF Income reported but invalid amount."
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
            AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
            AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
            AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
            -- Child to HMIS 4.02.2
            AND ${TABLE}.income_cash_is = 1
            AND ${TABLE}.income_tanf_is = 0
            AND ${TABLE}.income_tanf > 0;;
        label: "TANF Income reported but TANF Income amount is greater than 0."
      }
      else: "None"
    }
  }

  dimension: general_assistance_ga_error {
    label: "GA Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_income_ga}: General Assistance (GA)"
    group_label: "Income Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_income_ga}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_ga_is NOT IN (0, 1) ;;
        label: "Invalid selection for General Assistance Income"
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_ga_is = 1
              AND (${TABLE}.income_ga IS NULL AND ${TABLE}.income_ga < 1);;
        label: "General Assistance Income reported but invalid amount."
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_ga_is = 0
              AND (${TABLE}.income_ga IS NULL AND ${TABLE}.income_ga > 0);;
        label: "General Assistance Income reported but General Assistance Income amount is greater than 0."
      }
      else: "None"
    }
  }

  dimension: retirement_income_from_social_security_error {
    label: "Retirement Income from Social Security Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_income_ss_retirement}: Retirement Income from Social Security"
    group_label: "Income Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_income_ss_retirement}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_ss_retirement_is NOT IN (0, 1) ;;
        label: "Invalid selection for Retirement Income from Social Security Income"
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_ss_retirement_is = 1
              AND ${TABLE}.income_ss_retirement IS NULL AND ${TABLE}.income_ss_retirement < 1;;
        label: "Retirement Income from Social Security reported but invalid amount."
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_ss_retirement_is = 0
              AND ${TABLE}.income_ss_retirement > 0;;
        label: "Retirement Income from Social Security Income reported but Retirement Income from Social Security Income amount is greater than 0."
      }
      else: "None"
    }
  }

  dimension: pension_or_retirement_income_from_a_former_job_error {
    label: "Pension or Retirement Income from a former Job Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_income_private_pension}: Pension or Retirement Income from a former Job"
    group_label: "Income Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "4_2_14"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_private_pension_is NOT IN (0, 1) ;;
        label: "Invalid selection for Pension or Retirement Income from a former Job Income"
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_private_pension_is = 1
              AND (${TABLE}.income_private_pension IS NULL AND ${TABLE}.income_ss_retirement < 1);;
        label: "Pension or Retirement Income from a former Job reported but invalid amount."
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_private_pension_is = 0
              AND ${TABLE}.income_private_pension > 0;;
        label: "Pension or Retirement Income from a former Job Income reported but Pension or Retirement Income from a former Job Income amount is greater than 0."
      }
      else: "None"
    }
  }

  dimension: child_support_error {
    label: "Child Support Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_income_childsupport}: Child Support"
    group_label: "Income Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_income_childsupport}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_childsupport_is NOT IN (0, 1) ;;
        label: "Invalid selection for Child Support Income"
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_childsupport_is = 1
              AND (${TABLE}.income_childsupport IS NULL AND ${TABLE}.income_childsupport < 1);;
        label: "Child Support reported but invalid amount."
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_childsupport_is = 0
              AND ${TABLE}.income_childsupport > 0;;
        label: "Child Support Income reported but Child Support amount is greater than 0."
      }
      else: "None"
    }
  }

  dimension: alimony_and_other_spousal_support_error {
    label: "Alimony and Other Spousal Support Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_income_spousal_support}: Alimony and Other Spousal Support"
    group_label: "Income Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_income_spousal_support}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_spousal_support_is NOT IN (0, 1) ;;
        label: "Invalid selection for Alimony and Other Spousal Support Income"
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_spousal_support_is = 1
              AND (${TABLE}.income_spousal_support IS NULL AND ${TABLE}.income_spousal_support < 1);;
        label: "Alimony and Other Spousal Support reported but invalid amount."
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_spousal_support_is = 0
              AND ${TABLE}.income_spousal_support > 0;;
        label: "No Alimony and Other Spousal Support reported but Alimony and Other Spousal Support amount is greater than 0."
      }
      else: "None"
    }
  }

  dimension: other_income_source_error {
    label: "Other Income Source Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_income_other_source}: Other Income Source"
    group_label: "Income Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_income_other_source}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_other_is NOT IN (0, 1) ;;
        label: "Invalid selection for Other Income Source"
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_other_is = 1
              AND (${TABLE}.income_other IS NULL AND ${TABLE}.income_other < 1);;
        label: "Other Income Source reported but invalid amount."
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_other_is = 0
              AND ${TABLE}.income_other > 0;;
        label: "Other Income Source reported but Other Income Source amount is greater than 0."
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_other_is = 1
              AND CHAR_LENGTH(${TABLE}.income_other_source) < 2;;
        label: "Other Income source description is too short"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_2} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.02.2
              AND ${TABLE}.income_cash_is = 1
              AND ${TABLE}.income_other_is = 1
              AND (${TABLE}.income_other_source = "" AND LENGTH(${TABLE}.income_other_source) > 0);;
        label: "Other Income description is white-space"
      }
      else: "None"
    }
  }

  dimension: non_cash_benefits_from_any_source_error {
    label: "Non-Cash Benefits from Any Source Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_benefits_noncash}: Non-Cash Benefits from Any Source"
    group_label: "Non-Cash Benefits Income Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_benefits_noncash}"]
    case: {
      when: {
        sql: ${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_3} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- If parent is something besides "Yes"
              AND ${TABLE}.benefits_noncash != 1
              AND (
                    -- Then check each child.  If it is NULL or "No," it's all good.
                    -- Otherwise, flag an error.
                    (${TABLE}.benefit_snap IS NOT NULL AND ${TABLE}.benefit_snap != 0) OR
                    (${TABLE}.benefits_wic IS NOT NULL AND ${TABLE}.benefits_wic != 0) OR
                    (${TABLE}.benefits_tanf_childcare IS NOT NULL AND ${TABLE}.benefits_tanf_childcare != 0) OR
                    (${TABLE}.benefits_tanf_transportation IS NOT NULL AND ${TABLE}.benefits_tanf_transportation != 0) OR
                    (${TABLE}.benefits_tanf_other IS NOT NULL AND ${TABLE}.benefits_tanf_other != 0) OR
                    (${TABLE}.benefits_other IS NOT NULL AND ${TABLE}.benefits_other != 0)
              )
        ;;
        label: "Non-Cash Benefits from Any Source Error is not 'No,' but dependent fields contain value"
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_3} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              AND ${TABLE}.benefits_noncash IS NULL ;;
        label: "Null"
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_3} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              AND ${TABLE}.benefits_noncash NOT IN (0, 1) ;;
        label: "Invalid Non-Cash Benefits from Any Source Selected"
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_3} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              AND ${TABLE}.benefits_noncash = 8 ;;
        label: "Client doesn't know"
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_3} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              AND ${TABLE}.benefits_noncash = 9 ;;
        label: "Client refused"
      }
      when: {
        sql:${TABLE}.screen_type IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_3} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              AND ${TABLE}.benefits_noncash = 99 ;;
        label: "Data not collected"
      }
      else: "None"
    }
  }

  dimension: supplemental_nutrition_assistance_program_snap_error {
    label: "Supplemental Nutrition Assistance Program (SNAP) Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_benefits_snap}: Supplemental Nutrition Assistance Program (SNAP)"
    group_label: "Non-Cash Benefits Income Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS",  "@{hmis_ref_num_benefits_snap}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_3} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.03.2
              AND ${TABLE}.benefits_noncash = 1
              AND ${TABLE}.benefit_snap IS NULL ;;
        label: "Null"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_3} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.03.2
              AND ${TABLE}.benefits_noncash = 1
              AND ${TABLE}.benefit_snap NOT IN (0, 1) ;;
        label: "Invalid selection for SNAP Benefits"
      }
      else: "None"
    }
  }

  dimension: women_infants_and_children_wic_error {
    label: "Women, Infants, and Children (WIC) Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_benefits_wic}: Women, Infants, and Children (WIC)"
    group_label: "Non-Cash Benefits Income Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_benefits_wic}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_3} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.03.2
              AND ${TABLE}.benefits_noncash = 1
              AND ${TABLE}.benefits_wic IS NULL ;;
        label: "Null"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_3} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.03.2
              AND ${TABLE}.benefits_noncash = 1
              AND ${TABLE}.benefits_wic NOT IN (0, 1) ;;
        label: "Invalid selection for WIC Benefits"
      }
      else: "None"
    }
  }

  dimension: tanf_child_care_services_error {
    label: "TANF Child Care Services Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_benefits_tanf_childcare}: TANF Child Care Services"
    group_label: "Non-Cash Benefits Income Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_benefits_tanf_childcare}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_3} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.03.2
              AND ${TABLE}.benefits_noncash = 1
              AND ${TABLE}.benefits_tanf_childcare IS NULL ;;
        label: "Null"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_3} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.03.2
              AND ${TABLE}.benefits_noncash = 1
              AND ${TABLE}.benefits_tanf_childcare NOT IN (0, 1) ;;
        label: "Invalid selection for TANF Child Care Services"
      }
      else: "None"
    }
  }

  dimension: tanf_transportation_services_error {
    label: "TANF Transportation Services Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_benefits_tanf_transportation}: TANF Transportation Services"
    group_label: "Non-Cash Benefits Income Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_benefits_tanf_transportation}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_3} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.03.2
              AND ${TABLE}.benefits_noncash = 1
              AND ${TABLE}.benefits_tanf_transportation IS NULL ;;
        label: "Null"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_3} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.03.2
              AND ${TABLE}.benefits_noncash = 1
              AND ${TABLE}.benefits_tanf_transportation NOT IN (0, 1) ;;
        label: "Invalid selection for TANF Transportation Services"
      }
      else: "None"
    }
  }

  dimension: other_tanf_services_error {
    label: "Other TANF Services Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_benefits_tanf_other}: Other TANF Services"
    group_label: "Non-Cash Benefits Income Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_benefits_tanf_other}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_3} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.03.2
              AND ${TABLE}.benefits_noncash = 1
              AND ${TABLE}.benefits_tanf_other IS NULL ;;
        label: "Null"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_3} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.03.2
              AND ${TABLE}.benefits_noncash = 1
              AND ${TABLE}.benefits_tanf_other NOT IN (0, 1) ;;
        label: "Invalid selection for Other TANF Services"
      }
      else: "None"
    }
  }

  dimension: other_non_cash_benefits_error {
    label: "Other Non-Cash Benefits Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_benefits_other}: Other Non-Cash Benefits"
    group_label: "Non-Cash Benefits Income Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_benefits_other}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_3} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.03.2
              AND ${TABLE}.benefits_noncash = 1
              AND ${TABLE}.benefits_other IS NULL ;;
        label: "Null"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_3} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.03.2
              AND ${TABLE}.benefits_noncash = 1
              AND ${TABLE}.benefits_other NOT IN (0, 1) ;;
        label: "Invalid selection for Other TANF Services"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_3} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.03.2
              AND ${TABLE}.benefits_noncash = 1
              AND ${TABLE}.benefits_other = 1
              AND CHAR_LENGTH(${TABLE}.benefits_other_source) < 2;;
        label: "Other Benefits source description is too short"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_3} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.03.2
              AND ${TABLE}.benefits_noncash = 1
              AND ${TABLE}.benefits_other = 1
              AND (${TABLE}.benefits_other_source = "" AND LENGTH(${TABLE}.benefits_other_source) > 0);;
        label: "Other Benefits description is white-space"
      }
      else: "None"
    }
  }

  dimension: covered_by_health_insurance_error {
    label: "Covered by Health Insurance Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_health_insurance}: Covered by Health Insurance"
    group_label: "Health Insurance"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_health_insurance}"]

    case: {
      when: {
        sql:      ${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_4} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- If parent is something besides "Yes"
              AND ${TABLE}.health_insurance != 1
              AND (
                  -- Then check each child.  If it is NULL or "No," it's all good.
                  -- Otherwise, flag an error.
                  (${TABLE}.benefits_medicaid IS NOT NULL AND ${TABLE}.benefits_medicaid != 0) OR
                  (${TABLE}.benefits_medicare IS NOT NULL AND ${TABLE}.benefits_medicare != 0) OR
                  (${TABLE}.benefits_schip IS NOT NULL AND ${TABLE}.benefits_schip != 0) OR
                  (${TABLE}.benefits_va_medical IS NOT NULL AND ${TABLE}.benefits_va_medical != 0) OR
                  (${TABLE}.health_ins_emp IS NOT NULL AND ${TABLE}.health_ins_emp != 0) OR
                  (${TABLE}.health_ins_cobra IS NOT NULL AND ${TABLE}.health_ins_cobra != 0) OR
                  (${TABLE}.health_ins_ppay IS NOT NULL AND ${TABLE}.health_ins_ppay != 0) OR
                  (${TABLE}.health_ins_state IS NOT NULL AND ${TABLE}.health_ins_state != 0) OR
                  (${TABLE}.c_indian_health_service_program IS NOT NULL AND ${TABLE}.c_indian_health_service_program != 0) OR
                  (${TABLE}.other_health_insurance IS NOT NULL AND ${TABLE}.other_health_insurance != 0)
              )
        ;;
        label: "Covered by Health Insurance is not 'No,' but dependent fields contain value"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_4} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              AND ${TABLE}.health_insurance IS NULL ;;
        label: "Null"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_4} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              AND ${TABLE}.health_insurance IS NULL ;;
        label: "Null"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_4} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              AND ${TABLE}.health_insurance NOT IN (0, 1) ;;
        label: "Invalid selection Covered by Health Insurance"
      }
      else: "None"
    }
  }

  dimension: medicaid_error {
    label: "Medicaid Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_benefits_medicaid} and @{hmis_ref_num_hopwa_medicaid_reason}: Medicaid"
    group_label: "Health Insurance"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_benefits_medicaid}"]


    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_4} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.benefits_medicaid IS NULL ;;
        label: "Null"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_4} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.benefits_medicaid NOT IN (0, 1) ;;
        label: "Invalid selection for Medicaid benefits"
      }
      # HOPWA Only
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hopwa_only} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              AND ${TABLE}.benefits_medicaid = 0
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.hopwa_medicaid_reason NOT IN (1, 2, 3, 4);;
        label: "Invalid selection for No Medicaid Reason"
      }
      else: "None"
    }
  }

  dimension: medicare_error {
    label: "Medicare Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_benefits_medicare} and @{hmis_ref_num_hopwa_medicare_reason}: Medicare"
    group_label: "Health Insurance"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_benefits_medicare}"]
    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_4} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.benefits_medicare IS NULL ;;
        label: "Null"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_4} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.benefits_medicare NOT IN (0, 1) ;;
        label: "Invalid selection for Medicare benefits"
      }
      # HOPWA Only
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hopwa_only} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              AND ${TABLE}.benefits_medicare = 0
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.hopwa_medicare_reason NOT IN (1, 2, 3, 4);;
        label: "Invalid selection for No Medicare Reason"
      }
      else: "None"
    }
  }

  dimension: state_childrens_health_insurance_program_error {
    label: "State Children’s Health Insurance Program Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_benefits_schip} and @{hmis_ref_num_hopwa_schip_reason}: State Children’s Health Insurance Program"
    group_label: "Health Insurance"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_benefits_schip}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_4} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.benefits_schip IS NULL ;;
        label: "Null"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_4} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.benefits_schip NOT IN (0, 1) ;;
        label: "Invalid selection for State Children’s Health Insurance Program benefits"
      }
      # HOPWA Only
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hopwa_only} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              AND ${TABLE}.benefits_schip = 0
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.hopwa_schip_reason NOT IN (1, 2, 3, 4);;
        label: "Invalid selection for No State Children’s Health Insurance Program Reason"
      }
      else: "None"
    }
  }

  dimension: veterans_administration_va_medical_services_error {
    label: "Veteran’s Administration (VA) Medical Services Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_benefits_va_medical}: Veteran’s Administration (VA) Medical Services"
    group_label: "Health Insurance"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_benefits_va_medical}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_4} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.benefits_va_medical IS NULL ;;
        label: "Null"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_4} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.benefits_va_medical NOT IN (0, 1) ;;
        label: "Invalid selection for Veteran’s Administration (VA) Medical Services benefits"
      }
      # HOPWA Only
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hopwa_only} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              AND ${TABLE}.benefits_va_medical = 0
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.hopwa_va_medical_reason NOT IN (1, 2, 3, 4);;
        label: "Invalid selection for No Veteran’s Administration (VA) Medical Services Reason"
      }
      else: "None"
    }
  }

  dimension: employer_provided_health_insurance_error {
    label: "Employer Provided Health Insurance Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_health_ins_emp}: Employer Provided Health Insurance"
    group_label: "Health Insurance"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_health_ins_emp}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_4} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.health_ins_emp IS NULL ;;
        label: "Null"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_4} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.health_ins_emp NOT IN (0, 1) ;;
        label: "Invalid selection for Employer Provided Health Insurance"
      }
      # HOPWA Only
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hopwa_only} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.health_ins_emp = 0
              AND ${TABLE}.hopwa_emp_reason NOT IN (1, 2, 3, 4);;
        label: "Invalid selection for No Employer Provided Health Insurance Reason"
      }
      else: "None"
    }
  }

  dimension: health_insurance_obtained_through_cobra_error {
    label: "Health Insurance obtained through COBRA Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_health_ins_cobra}: Health Insurance obtained through COBRA"
    group_label: "Health Insurance"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_health_ins_cobra}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_4} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.health_ins_cobra IS NULL ;;
        label: "Null"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_4} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.health_ins_cobra NOT IN (0, 1) ;;
        label: "Invalid selection for COBRA"
      }
      # HOPWA Only
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hopwa_only} = 1
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.health_ins_cobra = 0
              AND ${TABLE}.hopwa_cobra_reason NOT IN (1, 2, 3, 4);;
        label: "Invalid selection for No COBRA Reason"
      }
      else: "None"
    }
  }

  dimension: private_pay_health_insurance_error {
    label: "Private Pay Health Insurance Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_health_ins_ppay}: Private Pay Health Insurance"
    group_label: "Health Insurance"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", " @{hmis_ref_num_health_ins_ppay}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_4} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.health_ins_ppay IS NULL ;;
        label: "Null"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_4} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.health_ins_ppay NOT IN (0, 1) ;;
        label: "Invalid selection for Private Pay Health Insurance"
      }
      # HOPWA Only
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hopwa_only} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.health_ins_ppay = 0
              AND ${TABLE}.hopwa_ppay_reason NOT IN (1, 2, 3, 4);;
        label: "Invalid selection for No Private Pay Health Insurance Reason"
      }
      else: "None"
    }
  }

  dimension: state_health_insurance_for_adults_error {
    label: "State Health Insurance for Adults Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_health_ins_state}: State Health Insurance for Adults"
    group_label: "Health Insurance"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_health_ins_state}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_4} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.health_ins_state IS NULL ;;
        label: "Null"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_4} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.health_ins_state NOT IN (0, 1) ;;
        label: "Invalid selection for State Health Insurance for Adults"
      }
      # HOPWA Only
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hopwa_only} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.health_ins_state = 0
              AND ${TABLE}.hopwa_state_reason NOT IN (1, 2, 3, 4);;
        label: "Invalid selection for No State Health Insurance for Adults Reason"
      }
      else: "None"
    }
  }

  dimension: indian_health_services_program_error {
    label: "Indian Health Services Program Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_c_indian_health_service_program}: Indian Health Services Program"
    group_label: "Health Insurance"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_c_indian_health_service_program}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_4} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.c_indian_health_service_program IS NULL ;;
        label: "Null"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_4} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.c_indian_health_service_program NOT IN (0, 1) ;;
        label: "Invalid selection for State Health Insurance for Adults"
      }
      # HOPWA Only
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hopwa_only} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.c_indian_health_service_program = 0
              AND ${TABLE}.indian_health_reason NOT IN (1, 2, 3, 4);;
        label: "Invalid selection for No State Health Insurance for Adults Reason"
      }
      else: "None"
    }
  }

  dimension: other_health_insurance_error {
    label: "Other Health Insurance Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_other_health_insurance_specify}: Other Health Insurance"
    group_label: "Health Insurance"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_other_health_insurance_specify}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_4} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.other_health_insurance IS NULL ;;
        label: "Null"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_4} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.other_health_insurance NOT IN (0, 1) ;;
        label: "Invalid Other Health Insurance Response Selected"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_4} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.other_health_insurance = 1
              AND CHAR_LENGTH(${TABLE}.other_health_insurance_specify) < 2;;
        label: "Other Health Insurance Response is too Short"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_annual}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_4} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              -- Child to HMIS 4.04.2
              AND ${TABLE}.health_insurance = 1
              AND ${TABLE}.other_health_insurance = 1
              AND (${TABLE}.other_health_insurance_specify = "" AND LENGTH(${TABLE}.other_health_insurance_specify) > 0) ;;
        label: "Other Health Insurance Description is White-space"
      }
      else: "None"
    }
  }

  dimension: domestic_violence_victim_or_survivor_error {
    label: "Domestic Violence Victim or Survivor Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_health_dv}-2B: Domestic Violence Victim or Survivor"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_health_dv}", "@{hmis_ref_num_health_dv_occurred}", "@{hmis_ref_num_health_dv_fleeing}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_11} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              AND ${TABLE}.health_dv IS NULL;;
        label: "Null"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_11} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              AND ${TABLE}.health_dv NOT IN (0, 1, 8, 9, 99);;
        label: "Invalid Domestic Violence Victim or Survivor Response Selected"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_11} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              AND ${TABLE}.health_dv = 1
              AND ${TABLE}.health_dv_occurred IS NULL;;
        label: "Null in How Recent Last Occurrence"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              AND ${dq_data_error_applies_to_program.hmis_4_11} = 1
              AND ${TABLE}.health_dv = 1
              AND ${TABLE}.health_dv_occurred NOT IN (1, 2, 3, 4, 8, 9, 99);;
        label: "Invalid Selection in How Recent Last Occurrence"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_11} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              AND ${TABLE}.health_dv = 1
              AND ${TABLE}.health_dv_fleeing IS NULL;;
        label: "Null in Currently Fleeing"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_11} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              AND ${TABLE}.health_dv = 1
              AND ${TABLE}.health_dv_fleeing NOT IN (0, 1, 8, 9, 99);;
        label: "Invalid Currently Fleeing Selection"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_11} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              AND ${TABLE}.health_dv = 8;;
        label: "Client doesn't know"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_11} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              AND ${TABLE}.health_dv = 9;;
        label: "Client Refused"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_11} = 1
              AND (${data_quality.age} >= 18 OR ${TABLE}.relationship_to_hoh = 1)
              AND ${TABLE}.health_dv = 99;;
        label: "Data Not Collected"
      }
      else: "None"
    }
  }

  dimension: physical_disability_error {
    label: "Physical Disability Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_health_phys_disability}: Physical Disability"
    group_label: "Disability Information Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_health_phys_disability}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_5} = 1
              AND ${TABLE}.health_phys_disability IS NULL;;
        label: "Null"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_5} = 1
              AND ${TABLE}.health_phys_disability NOT IN (0, 1, 8, 9, 99);;
        label: "Invalid selection"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_5} = 1
              AND ${TABLE}.health_phys_disability = 8;;
        label: "Client doesn't know"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_5} = 1
              AND ${TABLE}.health_phys_disability = 9;;
        label: "Client refused"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_5} = 1
              AND ${TABLE}.health_phys_disability = 99;;
        label: "Data Not Collected"
      }
      else: "None"
    }
  }

  dimension: physical_disability_impairs_error {
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_health_phys_disability_longterm}: Physical Disability Impairs Independent Living"
    group_label: "Disability Information Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_health_phys_disability_longterm}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_5} = 1
              AND ${TABLE}.health_phys_disability = 1
              AND ${TABLE}.health_phys_disability_longterm IS NULL;;
        label: "Null"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_5} = 1
              AND ${TABLE}.health_phys_disability = 1
              AND ${TABLE}.health_phys_disability_longterm NOT IN (0, 1, 8, 9, 99);;
        label: "Invalid selection"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_5} = 1
              AND ${TABLE}.health_phys_disability = 1
              AND ${TABLE}.health_phys_disability_longterm = 8;;
        label: "Client doesn't know"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_5} = 1
              AND ${TABLE}.health_phys_disability = 1
              AND ${TABLE}.health_phys_disability_longterm = 9;;
        label: "Client refused"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_5} = 1
              AND ${TABLE}.health_phys_disability = 1
              AND ${TABLE}.health_phys_disability_longterm = 99;;
        label: "Data Not Collected"
      }
      else: "None"
    }
  }

  dimension: developmental_disability_error {
    label: "Developmental Disability Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_health_dev_disability}: Developmental Disability"
    group_label: "Disability Information Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_health_dev_disability}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_6} = 1
              AND ${TABLE}.health_dev_disability IS NULL;;
        label: "Null"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_6} = 1
              AND ${TABLE}.health_dev_disability NOT IN (0, 1, 8, 9, 99);;
        label: "Invalid selection"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_6} = 1
              AND ${TABLE}.health_dev_disability = 8;;
        label: "Client doesn't know"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_6} = 1
              AND ${TABLE}.health_dev_disability = 9;;
        label: "Client refused"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_6} = 1
              AND ${TABLE}.health_dev_disability = 99;;
        label: "Data Not Collected"
      }
      else: "None"
    }
  }

  dimension: chronic_health_disability_error {
    label: "Chronic Health Condition Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_health_chronic}: Chronic Health Condition"
    group_label: "Disability Information Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_health_chronic}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_7} = 1
              AND ${TABLE}.health_chronic IS NULL;;
        label: "Null"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_7} = 1
              AND ${TABLE}.health_chronic NOT IN (0, 1, 8, 9, 99);;
        label: "Invalid selection"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_7} = 1
              AND ${TABLE}.health_chronic = 8;;
        label: "Client doesn't know"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_7} = 1
              AND ${TABLE}.health_chronic = 9;;
        label: "Client refused"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_7} = 1
              AND ${TABLE}.health_chronic = 99;;
        label: "Data Not Collected"
      }
      else: "None"
    }
  }

  dimension: chronic_health_disability_impairs_error {
    label: "Chronic Health Condition Impairs Ability to Live Independently Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_health_chronic_longterm}: Chronic Health Condition Impairs Independent Living"
    group_label: "Disability Information Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_health_chronic_longterm}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_7} = 1
              AND ${TABLE}.health_chronic = 1
              AND ${TABLE}.health_chronic_longterm IS NULL;;
        label: "Null"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_7} = 1
              AND ${TABLE}.health_chronic = 1
              AND ${TABLE}.health_chronic_longterm NOT IN (0, 1, 8, 9, 99);;
        label: "Invalid selection"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_7} = 1
              AND ${TABLE}.health_chronic = 1
              AND ${TABLE}.health_chronic_longterm = 8;;
        label: "Client doesn't know"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_7} = 1
              AND ${TABLE}.health_chronic = 1
              AND ${TABLE}.health_chronic_longterm = 9;;
        label: "Client refused"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_7} = 1
              AND ${TABLE}.health_chronic = 1
              AND ${TABLE}.health_chronic_longterm = 99;;
        label: "Data Not Collected"
      }
      else: "None"
    }
  }

  dimension: hiv_aids_error {
    label: "HIV/AIDS Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_health_hiv}: HIV / AIDS"
    group_label: "Disability Information Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_health_hiv}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_8} = 1
              AND ${TABLE}.health_hiv IS NULL;;
        label: "Null"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_8} = 1
              AND ${TABLE}.health_hiv NOT IN (0, 1, 8, 9, 99);;
        label: "Invalid selection"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_8} = 1
              AND ${TABLE}.health_hiv = 8;;
        label: "Client doesn't know"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_8} = 1
              AND ${TABLE}.health_hiv = 9;;
        label: "Client refused"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_8} = 1
              AND ${TABLE}.health_hiv = 99;;
        label: "Data Not Collected"
      }
      else: "None"
    }
  }

  dimension: mental_health_problem_error {
    label: "Mental Health Problem Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_health_mental}: Mental Health Problem"
    group_label: "Disability Information Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_health_mental}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_9} = 1
              AND ${TABLE}.health_mental IS NULL;;
        label: "Null"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_9} = 1
              AND ${TABLE}.health_mental NOT IN (0, 1, 8, 9, 99);;
        label: "Invalid selection"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_9} = 1
              AND ${TABLE}.health_mental = 8;;
        label: "Client doesn't know"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_9} = 1
              AND ${TABLE}.health_mental = 9;;
        label: "Client refused"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_9} = 1
              AND ${TABLE}.health_mental = 99;;
        label: "Data Not Collected"
      }
      else: "None"
    }
  }

  dimension: mental_health_problem_impairs_error {
    label: "Mental Health Problem Impairs Ability to Live Independently Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_health_mental_longterm}: Mental Health Problem Impairs Independent Living"
    group_label: "Disability Information Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_health_mental_longterm}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_9} = 1
              AND ${TABLE}.health_mental = 1
              AND ${TABLE}.health_mental_longterm IS NULL;;
        label: "Null"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_9} = 1
              AND ${TABLE}.health_mental = 1
              AND ${TABLE}.health_mental_longterm NOT IN (0, 1, 8, 9, 99);;
        label: "Invalid selection"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_9} = 1
              AND ${TABLE}.health_mental = 1
              AND ${TABLE}.health_mental_longterm = 8;;
        label: "Client doesn't know"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_9} = 1
              AND ${TABLE}.health_mental = 1
              AND ${TABLE}.health_mental_longterm = 9;;
        label: "Client refused"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_9} = 1
              AND ${TABLE}.health_mental = 1
              AND ${TABLE}.health_mental_longterm = 99;;
        label: "Data Not Collected"
      }
      else: "None"
    }
  }

  dimension: substance_abuse_error {
    label: "Substance Use Disorder Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_health_substance_abuse}: Substance Use Disorder"
    group_label: "Disability Information Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_health_substance_abuse}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_10} = 1
              AND ${TABLE}.health_substance_abuse IS NULL;;
        label: "Null"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_10} = 1
              AND ${TABLE}.health_substance_abuse NOT IN (0, 1, 2, 3, 8, 9, 99);;
        label: "Invalid selection"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_10} = 1
              AND ${TABLE}.health_substance_abuse = 8;;
        label: "Client doesn't know"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_10} = 1
              AND ${TABLE}.health_substance_abuse = 9;;
        label: "Client refused"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_10} = 1
              AND ${TABLE}.health_substance_abuse = 99;;
        label: "Data Not Collected"
      }
      else: "None"
    }
  }

  dimension: substance_abuse_impairs_error {
    label: "Substance Use Disorder Impairs Ability to Live Independently Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_health_substance_abuse_longterm}: Substance Use Disorder Impairs Ability to Live Independently"
    group_label: "Disability Information Errors"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_health_substance_abuse_longterm}"]

    case: {
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_10} = 1
              AND ${TABLE}.health_substance_abuse IN (1, 2, 3)
              AND ${TABLE}.health_substance_abuse_longterm IS NULL;;
        label: "Null"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_10} = 1
              AND ${TABLE}.health_substance_abuse IN (1, 2, 3)
              AND ${TABLE}.health_substance_abuse_longterm NOT IN (0, 1, 8, 9, 99);;
        label: "Invalid selection"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_10} = 1
              AND ${TABLE}.health_substance_abuse IN (1, 2, 3)
              AND ${TABLE}.health_substance_abuse_longterm = 8;;
        label: "Client doesn't know"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_10} = 1
              AND ${TABLE}.health_substance_abuse IN (1, 2, 3)
              AND ${TABLE}.health_substance_abuse_longterm = 9;;
        label: "Client refused"
      }
      when: {
        sql:${dq_client_program_demographics.screen_type} IN (${const_project_start}, ${const_project_update}, ${const_project_exit})
              AND (${TABLE}.status_screen_type != ${const_current_living_situation} OR ${TABLE}.status_screen_type is NULL)
              AND ${dq_data_error_applies_to_program.hmis_4_10} = 1
              AND ${TABLE}.health_substance_abuse IN (1, 2, 3)
              AND ${TABLE}.health_substance_abuse_longterm = 99;;
        label: "Data Not Collected"
      }
      else: "None"
    }
  }

  dimension: worst_housing_situation_error {
    label: "Worst Housing Situation Error"
    view_label: "DQ Client Program Specific"
    description: "Error in @{hmis_ref_num_rhsap_worst_housing}: Worst Housing Situation"
    alpha_sort: yes
    allow_fill: no
    tags: ["HMIS", "@{hmis_ref_num_rhsap_worst_housing}"]

    case: {
      when: {
        sql:     ${dq_client_program_demographics.screen_type} = ${const_project_start}
          AND ${funding_source.funding_source_code} = 12
          AND ${TABLE}.rhsap_worst_housing;;
        label: "Null"
      }
      when: {
        sql:     ${dq_client_program_demographics.screen_type} = ${const_project_start}
          AND ${funding_source.funding_source_code} = 12
          AND ${TABLE}.rhsap_worst_housing NOT IN (0, 1, 8, 9, 99);;
        label: "Worst Housing Situation selection is invalid"
      }
      when: {
        sql:     ${dq_client_program_demographics.screen_type} = ${const_project_start}
          AND ${funding_source.funding_source_code} = 12
          AND ${TABLE}.rhsap_worst_housing = 8;;
        label: "Client doesn't know"
      }
      when: {
        sql:     ${dq_client_program_demographics.screen_type} = ${const_project_start}
          AND ${funding_source.funding_source_code} = 12
          AND ${TABLE}.rhsap_worst_housing = 9;;
        label: "Client refused"
      }
      when: {
        sql:     ${dq_client_program_demographics.screen_type} = ${const_project_start}
          AND ${funding_source.funding_source_code} = 12
          AND ${TABLE}.rhsap_worst_housing = 99;;
        label: "Data not collected"
      }
      else: "None"
    }
  }

  dimension: exit_destination {
    alias: [dq_client_programs.last_exit_destination_text]
  }

  dimension: timeliness {
    label: "Data Entry Timeliness"
    description: "The number of days between data collection
    and entry in the HMIS, as an absolute value.
    Based loosely on guidance provided in the
    HMIS Reporting Glossary \"Q6. Timeliness\""
    sql: ABS(DATEDIFF(${TABLE}.added_date, ${TABLE}.program_date)) ;;
  }

  measure: average_timelineness {
    label: "Average Timeliness of Data Entry"
    description: "The average of the absolute value of days between
    data collected and entered in the HMIS. Based
    loosely on guidance provided in the HMIS
    Reporting Glossary \"Q6. Timeliness\""
    type:  average
    value_format: "0.00"
    sql: ${timeliness} ;;
  }

  dimension: move_in {
    # The group_label below is to override the "Retired" group_label
    group_label: ""
    description: "@{hmis_ref_num_move_in_date}"

  }

  measure: domestic_violence_victim_or_survivor_error_count {
    description: "Error in @{hmis_ref_num_health_dv}: Domestic Violence Victim or Survivor"
    view_label: "DQ Client Program Specific"
    group_label: ""
    type: count_distinct
    filters: {
      field: domestic_violence_victim_or_survivor_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, domestic_violence_victim_or_survivor_error, health_dv, health_dv_fleeing, health_dv_occurred]
    sql: ${id};;
  }

  measure: temporary_assistance_for_needy_families_tanf_error_count {
    label: "TANF Error Count"
    description: "Error in @{hmis_ref_num_income_tanf_is}: Temporary Assistance for Needy Families (TANF)"
    view_label: "DQ Client Program Specific"
    group_label: "Income Errors"
    type: count_distinct
    filters: {
      field: temporary_assistance_for_needy_families_tanf_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, temporary_assistance_for_needy_families_tanf_error, income_tanf_is, income_tanf]
    sql: ${id};;
  }

  measure: ssi_income_error_count {
    label: "SSI Income Error Count"
    description: "Error in @{hmis_ref_num_income_ssi_is}: SSI Income"
    view_label: "DQ Client Program Specific"
    group_label: "Income Errors"
    type: count_distinct
    filters: {
      field: ssi_income_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, ssi_income_error, income_ssi_is, income_ssi]
    sql: ${id};;
  }

  measure: physical_disability_error_count {
    description: "Error in @{hmis_ref_num_health_phys_disability}: Physical Disability"
    view_label: "DQ Client Program Specific"
    group_label: "Disability Information Errors"
    type: count_distinct
    filters: {
      field: physical_disability_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, physical_disability_error, health_phys_disability]
    sql: ${id};;
  }

  measure: workers_compensation_income_error_count {
    description: "Error in @{hmis_ref_num_income_workers_comp_is}: Worker’s Compensation Income"
    view_label: "DQ Client Program Specific"
    group_label: "Income Errors"
    type: count_distinct
    filters: {
      field: workers_compensation_income_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, workers_compensation_income_error, income_workers_comp_is, income_workers_comp ]
    sql: ${id};;
  }

  measure: total_monthly_income_error_count {
    description: "Error in @{hmis_ref_num_income_individual}: Total Monthly Income"
    view_label: "DQ Client Program Specific"
    group_label: "Income Errors"
    type: count_distinct
    filters: {
      field: total_monthly_income_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, total_monthly_income_error, income_cash_is, income_cash]
    sql: ${id};;
  }

  measure: tanf_child_care_services_error_count {
    label: "TANF Child Care Services Error Count"
    description: "Error in @{hmis_ref_num_benefits_tanf_childcare}: TANF Child Care Services"
    view_label: "DQ Client Program Specific"
    group_label: "Non-Cash Benefits Income Errors"
    type: count_distinct
    filters: {
      field: tanf_child_care_services_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, tanf_child_care_services_error, benefits_tanf_childcare]
    sql: ${id};;
  }

  measure: substance_abuse_impairs_error_count {
    label: "Substance Use Disorder Impairs Error Count"
    description: "Error in @{hmis_ref_num_health_substance_abuse}: Substance Use Disorder Impairs Ability to Live Independently"
    view_label: "DQ Client Program Specific"
    group_label: "Disability Information Errors"
    type: count_distinct
    filters: {
      field: substance_abuse_impairs_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, substance_abuse_impairs_error, health_substance_abuse_longterm]
    sql: ${id};;
  }

  measure: mental_health_problem_error_count {
    description: "Error in @{hmis_ref_num_health_mental}: Mental Health Problem"
    view_label: "DQ Client Program Specific"
    group_label: "Disability Information Errors"
    type: count_distinct
    filters: {
      field: mental_health_problem_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, mental_health_problem_error, health_mental]
    sql: ${id};;
  }

  measure: date_of_engagement_error_count {
    description: "Error in @{hmis_ref_num_path_engagement_date}: Date of Engagement"
    view_label: "DQ Client Program Specific"
    group_label: ""
    type: count_distinct
    filters: {
      field: date_of_engagement_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, date_of_engagement_error, path_engagement_date]
    sql: ${id};;
  }

  measure: general_assistance_ga_error_count {
    label: "GA Error Count"
    description: "Error in @{hmis_ref_num_income_ga_is}: General Assistance (GA)"
    view_label: "DQ Client Program Specific"
    group_label: "Income Errors"
    type: count_distinct
    filters: {
      field: general_assistance_ga_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, general_assistance_ga_error, income_ga_is, income_ga]
    sql: ${id};;
  }

  measure: medicaid_error_count {
    description: "Error in @{hmis_ref_num_benefits_medicaid}: Medicaid"
    view_label: "DQ Client Program Specific"
    group_label: "Health Insurance"
    type: count_distinct
    filters: {
      field: medicaid_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, medicaid_error, benefits_medicaid]
    sql: ${id};;
  }

  measure: state_childrens_health_insurance_program_error_count {
    description: "Error in @{hmis_ref_num_benefits_schip}: State Children’s Health Insurance Program"
    view_label: "DQ Client Program Specific"
    group_label: "Health Insurance"
    type: count_distinct
    filters: {
      field: state_childrens_health_insurance_program_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, state_childrens_health_insurance_program_error, benefits_schip]
    sql: ${id};;
  }

  measure: covered_by_health_insurance_error_count {
    description: "Error in @{hmis_ref_num_health_insurance}: Covered by Health Insurance"
    view_label: "DQ Client Program Specific"
    group_label: "Health Insurance"
    type: count_distinct
    filters: {
      field: covered_by_health_insurance_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, covered_by_health_insurance_error, health_insurance]
    sql: ${id};;
  }

  measure: private_pay_health_insurance_error_count {
    description: "Error in @{hmis_ref_num_health_ins_ppay}: Private Pay Health Insurance"
    view_label: "DQ Client Program Specific"
    group_label: "Health Insurance"
    type: count_distinct
    filters: {
      field: private_pay_health_insurance_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, private_pay_health_insurance_error, health_ins_ppay]
    sql: ${id};;
  }

  measure: hiv_aids_error_count {
    label: "HIV/AIDS Error Count"
    description: "Error in @{hmis_ref_num_health_hiv}: HIV / AIDS"
    view_label: "DQ Client Program Specific"
    group_label: "Disability Information Errors"
    type: count_distinct
    filters: {
      field: hiv_aids_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, hiv_aids_error, health_hiv]
    sql: ${id};;
  }

  measure: non_cash_benefits_from_any_source_error_count {
    description: "Error in @{hmis_ref_num_benefits_noncash}: Non-Cash Benefits from Any Source"
    view_label: "DQ Client Program Specific"
    group_label: "Non-Cash Benefits Income Errors"
    type: count_distinct
    filters: {
      field: non_cash_benefits_from_any_source_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, non_cash_benefits_from_any_source_error, benefits_noncash]
    sql: ${id};;
  }

  measure: supplemental_nutrition_assistance_program_snap_error_count {
    label: "Supplemental Nutrition Assistance Program (SNAP) Error Count"
    description: "Error in @{hmis_ref_num_benefits_snap}: Supplemental Nutrition Assistance Program (SNAP)"
    view_label: "DQ Client Program Specific"
    group_label: "Non-Cash Benefits Income Errors"
    type: count_distinct
    filters: {
      field: supplemental_nutrition_assistance_program_snap_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, supplemental_nutrition_assistance_program_snap_error, benefit_snap]
    sql: ${id};;
  }

  measure: developmental_disability_error_count {
    description: "Error in @{hmis_ref_num_health_dev_disability}: Developmental Disability"
    view_label: "DQ Client Program Specific"
    group_label: "Disability Information Errors"
    type: count_distinct
    filters: {
      field: developmental_disability_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, developmental_disability_error, health_dev_disability]
    sql: ${id};;
  }

  measure: retirement_income_from_social_security_error_count {
    description: "Error in @{hmis_ref_num_income_ss_retirement_is}: Retirement Income from Social Security"
    view_label: "DQ Client Program Specific"
    group_label: "Income Errors"
    type: count_distinct
    filters: {
      field: retirement_income_from_social_security_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, retirement_income_from_social_security_error, income_ss_retirement_is, income_ss_retirement]
    sql: ${id};;
  }

  measure: tanf_transportation_services_error_count {
    label: "TANF Transportation Services Error Count"
    description: "Error in @{hmis_ref_num_benefits_tanf_transportation}: TANF Transportation Services"
    view_label: "DQ Client Program Specific"
    group_label: "Non-Cash Benefits Income Errors"
    type: count_distinct
    filters: {
      field: tanf_transportation_services_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, tanf_transportation_services_error, benefits_tanf_transportation]
    sql: ${id};;
  }

  measure: alimony_and_other_spousal_support_error_count {
    description: "Error in @{hmis_ref_num_income_spousal_support_is}: Alimony and Other Spousal Support"
    view_label: "DQ Client Program Specific"
    group_label: "Income Errors"
    type: count_distinct
    filters: {
      field: alimony_and_other_spousal_support_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, alimony_and_other_spousal_support_error, income_spousal_support_is, income_spousal_support]
    sql: ${id};;
  }

  measure: chronic_health_disability_impairs_error_count {
    description: "Error in @{hmis_ref_num_health_chronic}: Chronic Health Condition Impairs Independent Living"
    view_label: "DQ Client Program Specific"
    group_label: "Disability Information Errors"
    type: count_distinct
    filters: {
      field: chronic_health_disability_impairs_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, chronic_health_disability_impairs_error, health_chronic_longterm]
    sql: ${id};;
  }

  measure: va_service_connected_disability_compensation_income_error_count {
    label: "VA Service-Connected Disability Compensation Income Count"
    description: "Error in @{hmis_ref_num_income_vet_disability_is}: VA Service-Connected Disability Compensation Income"
    view_label: "DQ Client Program Specific"
    group_label: "Income Errors"
    type: count_distinct
    filters: {
      field: va_service_connected_disability_compensation_income_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, va_service_connected_disability_compensation_income_error, income_vet_disability_is, income_vet_disability]
    sql: ${id};;
  }

  measure: mental_health_problem_impairs_error_count {
    description: "Error in @{hmis_ref_num_health_mental_longterm}: Mental Health Problem Impairs Independent Living"
    view_label: "DQ Client Program Specific"
    group_label: "Disability Information Errors"
    type: count_distinct
    filters: {
      field: mental_health_problem_impairs_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, mental_health_problem_impairs_error, health_mental_longterm]
    sql: ${id};;
  }

  measure: other_health_insurance_error_count {
    description: "Error in @{hmis_ref_num_other_health_insurance_specify}: Other Health Insurance"
    view_label: "DQ Client Program Specific"
    group_label: "Health Insurance"
    type: count_distinct
    filters: {
      field: other_health_insurance_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, other_health_insurance_error]
    sql: ${id};;
  }

  measure: earned_income_error_count {
    description: "Error in @{hmis_ref_num_income_earned_is}: Earned Income"
    view_label: "DQ Client Program Specific"
    group_label: "Income Errors"
    type: count_distinct
    filters: {
      field: earned_income_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, earned_income_error, income_earned_is, income_earned]
    sql: ${id};;
  }

  measure: physical_disability_impairs_error_count {
    description: "Error in @{hmis_ref_num_health_phys_disability_longterm}: Physical Disability Impairs Independent Living"
    view_label: "DQ Client Program Specific"
    group_label: "Disability Information Errors"
    type: count_distinct
    filters: {
      field: physical_disability_impairs_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, physical_disability_impairs_error, health_phys_disability_longterm]
    sql: ${id};;
  }

  measure: other_income_source_error_count {
    description: "Error in @{hmis_ref_num_income_other_source}: Other Income Source"
    view_label: "DQ Client Program Specific"
    group_label: "Income Errors"
    type: count_distinct
    filters: {
      field: other_income_source_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, other_income_source_error, income_other_is, income_other]
    sql: ${id};;
  }

  measure: child_support_error_count {
    description: "Error in @{hmis_ref_num_income_childsupport_is}: Child Support"
    view_label: "DQ Client Program Specific"
    group_label: "Income Errors"
    type: count_distinct
    filters: {
      field: child_support_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, child_support_error, income_childsupport_is, income_childsupport_is]
    sql: ${id};;
  }

  measure: veterans_administration_va_medical_services_error_count {
    label: "Veteran’s Administration (VA) Medical Services Error Count"
    description: "Error in @{hmis_ref_num_benefits_va_medical}: Veteran’s Administration (VA) Medical Services"
    view_label: "DQ Client Program Specific"
    group_label: "Health Insurance"
    type: count_distinct
    filters: {
      field: veterans_administration_va_medical_services_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, veterans_administration_va_medical_services_error, benefits_va_medical]
    sql: ${id};;
  }

  measure: medicare_error_count {
    description: "Error in @{hmis_ref_num_benefits_medicare}: Medicare"
    view_label: "DQ Client Program Specific"
    group_label: "Health Insurance"
    type: count_distinct
    filters: {
      field: medicare_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, medicare_error, benefits_medicare]
    sql: ${id};;
  }

  measure: private_disability_insurance_income_error_count {
    description: "Error in @{hmis_ref_num_income_private_disability_is}: Private Disability Insurance Income"
    view_label: "DQ Client Program Specific"
    group_label: "Income Errors"
    type: count_distinct
    filters: {
      field: private_disability_insurance_income_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, private_disability_insurance_income_error, health_ins_ppay]
    sql: ${id};;
  }


  measure: unemployment_income_error_count {
    description: "Error in @{hmis_ref_num_income_unemployment_is}: Unemployment Income"
    view_label: "DQ Client Program Specific"
    group_label: "Income Errors"
    type: count_distinct
    filters: {
      field: unemployment_income_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, unemployment_income_error, income_unemployment_is, income_unemployment]
    sql: ${id};;
  }

  measure: employer_provided_health_insurance_error_count {
    description: "Error in @{hmis_ref_num_health_ins_emp}: Employer Provided Health Insurance"
    view_label: "DQ Client Program Specific"
    group_label: "Health Insurance"
    type: count_distinct
    filters: {
      field: employer_provided_health_insurance_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, employer_provided_health_insurance_error, health_ins_emp]
    sql: ${id};;
  }

  measure: state_health_insurance_for_adults_error_count {
    description: "Error in @{hmis_ref_num_health_ins_state}: State Health Insurance for Adults"
    view_label: "DQ Client Program Specific"
    group_label: "Health Insurance"
    type: count_distinct
    filters: {
      field: state_health_insurance_for_adults_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, state_health_insurance_for_adults_error, health_ins_state]
    sql: ${id};;
  }

  measure: chronic_health_disability_error_count {
    description: "Error in @{hmis_ref_num_health_chronic}: Chronic Health Condition"
    view_label: "DQ Client Program Specific"
    group_label: "Disability Information Errors"
    type: count_distinct
    filters: {
      field: chronic_health_disability_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, chronic_health_disability_error, health_chronic]
    sql: ${id};;
  }

  measure: income_from_any_source_error_count {
    description: "Error in @{hmis_ref_num_any_income}: Income from Any Source"
    view_label: "DQ Client Program Specific"
    group_label: "Income Errors"
    type: count_distinct
    filters: {
      field: income_from_any_source_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, income_from_any_source_error, income_cash_is, income_cash]
    sql: ${id};;
  }

  measure: health_insurance_obtained_through_cobra_error_count {
    label: "Health Insurance obtained through COBRA Error Count"
    description: "Error in @{hmis_ref_num_health_ins_cobra}: Health Insurance obtained through COBRA"
    view_label: "DQ Client Program Specific"
    group_label: "Health Insurance"
    type: count_distinct
    filters: {
      field: health_insurance_obtained_through_cobra_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, health_insurance_obtained_through_cobra_error, health_ins_cobra]
    sql: ${id};;
  }

  measure: pension_or_retirement_income_from_a_former_job_error_count {
    description: "Error in @{hmis_ref_num_income_private_pension_is}: Pension or Retirement Income from a former Job"
    view_label: "DQ Client Program Specific"
    group_label: "Income Errors"
    type: count_distinct
    filters: {
      field: pension_or_retirement_income_from_a_former_job_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, pension_or_retirement_income_from_a_former_job_error,  income_private_pension_is, income_private_pension]
    sql: ${id};;
  }

  measure: other_tanf_services_error_count {
    label: "Other TANF Services Error Count"
    description: "Error in @{hmis_ref_num_benefits_tanf_other}: Other TANF Services"
    view_label: "DQ Client Program Specific"
    group_label: "Non-Cash Benefits Income Errors"
    type: count_distinct
    filters: {
      field: other_tanf_services_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, other_tanf_services_error, benefits_tanf_other]
    sql: ${id};;
  }

  measure: other_non_cash_benefits_error_count {
    description: "Error in @{hmis_ref_num_benefits_other}: Other Non-Cash Benefits"
    view_label: "DQ Client Program Specific"
    group_label: "Non-Cash Benefits Income Errors"
    type: count_distinct
    filters: {
      field: other_non_cash_benefits_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, other_non_cash_benefits_error, benefits_other]
    sql: ${id};;
  }

  measure: indian_health_services_program_error_count {
    description: "Error in @{hmis_ref_num_c_indian_health_service_program}: Indian Health Services Program"
    view_label: "DQ Client Program Specific"
    group_label: "Health Insurance"
    type: count_distinct
    filters: {
      field: indian_health_services_program_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, indian_health_services_program_error]
    sql: ${id};;
  }

  measure: ssdi_income_error_count {
    label: "SSDI Income Error Count"
    description: "Error in @{hmis_ref_num_income_ssdi_is}: SSDI Income"
    view_label: "DQ Client Program Specific"
    group_label: "Income Errors"
    type: count_distinct
    filters: {
      field: ssdi_income_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, ssdi_income_error, income_ssdi_is, income_ssdi]
    sql: ${id};;
  }

  measure: substance_abuse_error_count {
    label: "Substance Use Disorder Error Count"
    description: "Error in @{hmis_ref_num_health_substance_abuse}: Substance Use Disorder"
    view_label: "DQ Client Program Specific"
    group_label: "Disability Information Errors"
    type: count_distinct
    filters: {
      field: substance_abuse_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, substance_abuse_error, health_substance_abuse]
    sql: ${id};;
  }

  measure: women_infants_and_children_wic_error_count {
    label: "Women, Infants, and Children (WIC) Error Count"
    description: "Error in @{hmis_ref_num_benefits_wic}: Women, Infants, and Children (WIC)"
    view_label: "DQ Client Program Specific"
    group_label: "Non-Cash Benefits Income Errors"
    type: count_distinct
    filters: {
      field: women_infants_and_children_wic_error
      value: "-None"
    }
    drill_fields: [dq_client_program_demographics_drills*, women_infants_and_children_wic_error, benefits_wic]
    sql: ${id};;
  }

  measure: total_disability_information_errors_count {
    view_label: "Aggregates"
    type: number
    sql:    ${physical_disability_error_count} +
          ${substance_abuse_impairs_error_count} +
          ${mental_health_problem_error_count} ++
          ${hiv_aids_error_count} +
          ${developmental_disability_error_count} +
          ${chronic_health_disability_impairs_error_count} +
          ${mental_health_problem_impairs_error_count} +
          ${physical_disability_impairs_error_count} +
          ${chronic_health_disability_error_count} +
          ${substance_abuse_error_count}
    ;;

      drill_fields: [dq_project_descriptor.name,
        physical_disability_error_count,
        substance_abuse_impairs_error_count,
        mental_health_problem_error_count,
        hiv_aids_error_count,
        developmental_disability_error_count,
        chronic_health_disability_impairs_error_count,
        mental_health_problem_impairs_error_count,
        physical_disability_impairs_error_count,
        chronic_health_disability_error_count,
        substance_abuse_error_count

      ]
    }

    measure: total_income_errors_count {
      view_label: "Aggregates"
      type: number
      sql:    ${temporary_assistance_for_needy_families_tanf_error_count} +
          ${ssi_income_error_count} +
          ${workers_compensation_income_error_count} +
          ${total_monthly_income_error_count} +
          ${general_assistance_ga_error_count} +
          ${retirement_income_from_social_security_error_count} +
          ${alimony_and_other_spousal_support_error_count} +
          ${va_service_connected_disability_compensation_income_error_count} +
          ${earned_income_error_count} +
          ${other_income_source_error_count} +
          ${child_support_error_count} +
          ${private_disability_insurance_income_error_count} +
          ${unemployment_income_error_count} +
          ${income_from_any_source_error_count} +
          ${pension_or_retirement_income_from_a_former_job_error_count} +
          ${ssdi_income_error_count}
      ;;

        drill_fields: [
          temporary_assistance_for_needy_families_tanf_error_count,
          ssi_income_error_count,
          workers_compensation_income_error_count,
          total_monthly_income_error_count,
          general_assistance_ga_error_count,
          retirement_income_from_social_security_error_count,
          alimony_and_other_spousal_support_error_count,
          va_service_connected_disability_compensation_income_error_count,
          earned_income_error_count,
          other_income_source_error_count,
          child_support_error_count,
          private_disability_insurance_income_error_count,
          unemployment_income_error_count,
          income_from_any_source_error_count,
          pension_or_retirement_income_from_a_former_job_error_count,
          ssdi_income_error_count

        ]
      }

      measure: total_health_insurance_count {
        view_label: "Aggregates"
        type: number
        sql:    ${medicaid_error_count} +
                  ${state_childrens_health_insurance_program_error_count} +
                  ${covered_by_health_insurance_error_count} +
                  ${private_pay_health_insurance_error_count} +
                  ${other_health_insurance_error_count} +
                  ${veterans_administration_va_medical_services_error_count} +
                  ${medicare_error_count} +
                  ${employer_provided_health_insurance_error_count} +
                  ${state_health_insurance_for_adults_error_count} +
                  ${health_insurance_obtained_through_cobra_error_count} +
                  ${indian_health_services_program_error_count}
              ;;

          drill_fields: [
            medicaid_error_count,
            state_childrens_health_insurance_program_error_count,
            covered_by_health_insurance_error_count,
            private_pay_health_insurance_error_count,
            other_health_insurance_error_count,
            veterans_administration_va_medical_services_error_count,
            medicare_error_count,
            employer_provided_health_insurance_error_count,
            state_health_insurance_for_adults_error_count,
            health_insurance_obtained_through_cobra_error_count,
            indian_health_services_program_error_count

          ]
        }

        measure: total_non_cash_benefits_income_errors_count {
          view_label: "Aggregates"
          type: number
          sql:    ${tanf_child_care_services_error_count} +
                      ${non_cash_benefits_from_any_source_error_count} +
                      ${supplemental_nutrition_assistance_program_snap_error_count} +
                      ${tanf_transportation_services_error_count} +
                      ${other_tanf_services_error_count} +
                      ${other_non_cash_benefits_error_count} +
                      ${women_infants_and_children_wic_error_count}
                  ;;

            drill_fields: [
              tanf_child_care_services_error_count,
              non_cash_benefits_from_any_source_error_count,
              supplemental_nutrition_assistance_program_snap_error_count,
              tanf_transportation_services_error_count,
              other_tanf_services_error_count,
              other_non_cash_benefits_error_count,
              women_infants_and_children_wic_error_count

            ]
          }

          measure: count {
            view_label: "Data Collection Stage"
            label: "Number of Data Collection Assessments"
            description: "Count of the number of HUD Assessments of any type (Entry, Update, Exit, etc.)"
            type: count
          }

          dimension: enrollment_has_error {
            hidden: yes
            sql: CASE WHEN (

              ${alimony_and_other_spousal_support_error} != 'None'
              OR ${child_support_error} != 'None'
              OR ${chronic_health_disability_error} != 'None'
              OR ${chronic_health_disability_impairs_error} != 'None'
              OR ${covered_by_health_insurance_error} != 'None'
              OR ${date_of_engagement_error} != 'None'
              OR ${developmental_disability_error} != 'None'
              OR ${domestic_violence_victim_or_survivor_error} != 'None'
              OR ${earned_income_error} != 'None'
              OR ${employer_provided_health_insurance_error} != 'None'
              OR ${general_assistance_ga_error} != 'None'
              OR ${health_insurance_obtained_through_cobra_error} != 'None'
              OR ${hiv_aids_error} != 'None'
              OR ${income_from_any_source_error} != 'None'
              OR ${indian_health_services_program_error} != 'None'
              OR ${medicaid_error} != 'None'
              OR ${medicare_error} != 'None'
              OR ${mental_health_problem_error} != 'None'
              OR ${mental_health_problem_impairs_error} != 'None'
              OR ${non_cash_benefits_from_any_source_error} != 'None'
              OR ${other_health_insurance_error} != 'None'
              OR ${other_income_source_error} != 'None'
              OR ${other_non_cash_benefits_error} != 'None'
              OR ${other_tanf_services_error} != 'None'
              OR ${pension_or_retirement_income_from_a_former_job_error} != 'None'
              OR ${physical_disability_error} != 'None'
              OR ${physical_disability_impairs_error} != 'None'
              OR ${private_disability_insurance_income_error} != 'None'
              OR ${private_pay_health_insurance_error} != 'None'
              OR ${retirement_income_from_social_security_error} != 'None'
              OR ${ssdi_income_error} != 'None'
              OR ${ssi_income_error} != 'None'
              OR ${state_childrens_health_insurance_program_error} != 'None'
              OR ${state_health_insurance_for_adults_error} != 'None'
              OR ${substance_abuse_error} != 'None'
              OR ${substance_abuse_impairs_error} != 'None'
              OR ${supplemental_nutrition_assistance_program_snap_error} != 'None'
              OR ${tanf_child_care_services_error} != 'None'
              OR ${tanf_transportation_services_error} != 'None'
              OR ${temporary_assistance_for_needy_families_tanf_error} != 'None'
              OR ${unemployment_income_error} != 'None'
              OR ${va_service_connected_disability_compensation_income_error} != 'None'
              OR ${veterans_administration_va_medical_services_error} != 'None'
              OR ${women_infants_and_children_wic_error} != 'None'
              OR ${workers_compensation_income_error} != 'None'
              OR ${worst_housing_situation_error} != 'None'
            )
            THEN "Yes"
            ELSE "No"
            END ;;

          }

          measure: enrollments_with_error {
            label: "Count of Enrollments With Error"
            description: "Distinct count of enrollments with an error."
            type: count
            filters: [enrollment_has_error: "Yes"]
            drill_fields: [enrollment_id,
              ref_client,
              alimony_and_other_spousal_support_error,
              child_support_error,
              chronic_health_disability_error,
              chronic_health_disability_impairs_error,
              covered_by_health_insurance_error,
              date_of_engagement_error,
              developmental_disability_error,
              domestic_violence_victim_or_survivor_error,
              earned_income_error,
              employer_provided_health_insurance_error,
              general_assistance_ga_error,
              health_insurance_obtained_through_cobra_error,
              hiv_aids_error,
              income_from_any_source_error,
              indian_health_services_program_error,
              medicaid_error,
              medicare_error,
              mental_health_problem_error,
              mental_health_problem_impairs_error,
              non_cash_benefits_from_any_source_error,
              other_health_insurance_error,
              other_income_source_error,
              other_non_cash_benefits_error,
              other_tanf_services_error,
              pension_or_retirement_income_from_a_former_job_error,
              physical_disability_error,
              physical_disability_impairs_error,
              private_disability_insurance_income_error,
              private_pay_health_insurance_error,
              retirement_income_from_social_security_error,
              ssdi_income_error,
              ssi_income_error,
              state_childrens_health_insurance_program_error,
              state_health_insurance_for_adults_error,
              substance_abuse_error,
              substance_abuse_impairs_error,
              supplemental_nutrition_assistance_program_snap_error,
              tanf_child_care_services_error,
              tanf_transportation_services_error,
              temporary_assistance_for_needy_families_tanf_error,
              unemployment_income_error,
              va_service_connected_disability_compensation_income_error,
              veterans_administration_va_medical_services_error,
              women_infants_and_children_wic_error,
              workers_compensation_income_error,
              worst_housing_situation_error]
            sql_distinct_key: ${enrollment_id};;
          }

          set: dq_client_program_demographics_error_fields {
            fields: [
              alimony_and_other_spousal_support_error,
              alimony_and_other_spousal_support_error_count,
              child_support_error,
              child_support_error_count,
              chronic_health_disability_error,
              chronic_health_disability_error_count,
              chronic_health_disability_impairs_error,
              chronic_health_disability_impairs_error_count,
              covered_by_health_insurance_error,
              covered_by_health_insurance_error_count,
              date_of_engagement_error,
              date_of_engagement_error_count,
              developmental_disability_error,
              developmental_disability_error_count,
              domestic_violence_victim_or_survivor_error,
              domestic_violence_victim_or_survivor_error_count,
              earned_income_error,
              earned_income_error_count,
              employer_provided_health_insurance_error,
              employer_provided_health_insurance_error_count,
              general_assistance_ga_error,
              general_assistance_ga_error_count,
              health_insurance_obtained_through_cobra_error,
              health_insurance_obtained_through_cobra_error_count,
              hiv_aids_error,
              hiv_aids_error_count,
              income_from_any_source_error,
              income_from_any_source_error_count,
              indian_health_services_program_error,
              indian_health_services_program_error_count,
              medicaid_error,
              medicaid_error_count,
              medicare_error,
              medicare_error_count,
              mental_health_problem_error,
              mental_health_problem_error_count,
              mental_health_problem_impairs_error,
              mental_health_problem_impairs_error_count,
              non_cash_benefits_from_any_source_error,
              non_cash_benefits_from_any_source_error_count,
              other_health_insurance_error,
              other_health_insurance_error_count,
              other_income_source_error,
              other_income_source_error_count,
              other_non_cash_benefits_error,
              other_non_cash_benefits_error_count,
              other_tanf_services_error,
              other_tanf_services_error_count,
              pension_or_retirement_income_from_a_former_job_error,
              pension_or_retirement_income_from_a_former_job_error_count,
              physical_disability_error,
              physical_disability_error_count,
              physical_disability_impairs_error,
              physical_disability_impairs_error_count,
              private_disability_insurance_income_error,
              private_disability_insurance_income_error_count,
              private_pay_health_insurance_error,
              private_pay_health_insurance_error_count,
              retirement_income_from_social_security_error,
              retirement_income_from_social_security_error_count,
              ssdi_income_error,
              ssdi_income_error_count,
              ssi_income_error,
              ssi_income_error_count,
              state_childrens_health_insurance_program_error,
              state_childrens_health_insurance_program_error_count,
              state_health_insurance_for_adults_error,
              state_health_insurance_for_adults_error_count,
              substance_abuse_error,
              substance_abuse_error_count,
              substance_abuse_impairs_error,
              substance_abuse_impairs_error_count,
              supplemental_nutrition_assistance_program_snap_error,
              supplemental_nutrition_assistance_program_snap_error_count,
              tanf_child_care_services_error,
              tanf_child_care_services_error_count,
              tanf_transportation_services_error,
              tanf_transportation_services_error_count,
              temporary_assistance_for_needy_families_tanf_error,
              temporary_assistance_for_needy_families_tanf_error_count,
              total_disability_information_errors_count,
              total_income_errors_count,
              total_monthly_income_error,
              total_monthly_income_error_count,
              total_non_cash_benefits_income_errors_count,
              unemployment_income_error,
              unemployment_income_error_count,
              va_service_connected_disability_compensation_income_error,
              va_service_connected_disability_compensation_income_error_count,
              veterans_administration_va_medical_services_error,
              veterans_administration_va_medical_services_error_count,
              women_infants_and_children_wic_error,
              women_infants_and_children_wic_error_count,
              workers_compensation_income_error,
              workers_compensation_income_error_count,
              worst_housing_situation_error,
              enrollments_with_error,
              enrollment_has_error
            ]
          }

          set: dq_client_program_demographics_non_error_fields {
            fields: [
# Fields used in more than one dq view file
            health_hiv,
            relationship_to_hoh,

# Fields for dq_client_program_demographics
            benefits_medicaid,
            benefits_medicare,
            benefits_noncash,
            benefits_other,
            benefits_other_source,
            benefits_private_insurance,
            benefits_schip,
            benefits_tanf_childcare,
            benefits_tanf_other,
            benefits_tanf_transportation,
            benefits_va_medical,
            benefits_wic,
            c_indian_health_service_program,
            data_collection_stage,
            data_collection_stage_created_date_date,
            data_collection_stage_created_date_week,
            data_collection_stage_created_date_month,
            data_collection_stage_created_date_year,
            data_collection_stage_updated_date_date,
            data_collection_stage_updated_date_week,
            data_collection_stage_updated_date_month,
            data_collection_stage_updated_date_year,
            health_chronic,
            health_chronic_longterm,
            health_dev_disability,
            health_dv,
            health_dv_fleeing,
            health_dv_occurred,
            health_ins_cobra,
            health_ins_emp,
            health_ins_state,
            health_insurance,
            health_mental,
            health_mental_longterm,
            health_phys_disability,
            health_phys_disability_longterm,
            health_substance_abuse,
            health_substance_abuse_longterm,
            hopwa_cobra_reason,
            hopwa_emp_reason,
            hopwa_medicaid_reason,
            hopwa_medicare_reason,
            hopwa_ppay_reason,
            hopwa_schip_reason,
            hopwa_state_reason,
            hopwa_va_medical_reason,
            id,
            income_cash_is,
            income_childsupport,
            income_childsupport_is,
            income_earned,
            income_earned_is,
            income_ga,
            income_ga_is,
            income_individual,
            income_other,
            income_other_is,
            income_other_source,
            income_private_disability,
            income_private_disability_is,
            income_private_pension,
            income_private_pension_is,
            income_spousal_support,
            income_spousal_support_is,
            income_ss_retirement,
            income_ss_retirement_is,
            income_ssdi,
            income_ssdi_is,
            income_ssi,
            income_ssi_is,
            income_tanf,
            income_tanf_is,
            income_unemployment,
            income_unemployment_is,
            income_vet_disability,
            income_vet_disability_is,
            income_workers_comp,
            income_workers_comp_is,
            indian_health_reason,
            move_in_date,
            move_in_week,
            move_in_month,
            other_health_insurance,
            other_health_insurance_specify,
            path_engagement_date,
            rhsap_worst_housing,
            status_assessment_type,
            total_health_insurance_count,
            acceptable_exit,
            age,
            age_tier,
            any_disability,
            any_income,
            average_cash_income,
            average_income_earned,
            disabled,
            disabling_condition,
            entered_stably_housed,
            exit_destination_text,
            exit_type,
            housed_on_exit,
            is_latest_move_in_date,
            prior_duration_text,
            prior_residence_text,
            program_date,
            rhy_school_status,
            total_adults,
            total_cash_income,
            total_children,
            total_income_earned,
            total_unemployment_income,
            total_workers_comp_income,
            count,
            timeliness,
            average_timelineness,
            enrollment_id,
            ref_client
          ]
        }

        set: dq_client_program_demographics_master_set {
          fields: [
            dq_client_program_demographics_error_fields*,
            dq_client_program_demographics_non_error_fields*,
            dq_hopwa_error_fields*,
            dq_hopwa_non_error_fields*,
            dq_path_error_fields*,
            dq_path_non_error_fields*,
            dq_rhy_error_fields*,
            dq_rhy_non_error_fields*,
            dq_ssvf_error_fields*,
            dq_ssvf_non_error_fields*,
            dq_ude_error_fields*,
            dq_ude_non_error_fields*
          ]
        }
      }
