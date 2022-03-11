include: "dq_constants.view.lkml"
view: dq_client_program_demographics {

    dimension: yomomma {
        sql: ${TABLE}.duh ;;
    }

    dimension_group: created {
        type: time
        timeframes: [time, date, week, month, raw]
        sql: ${TABLE}.created_at ;;
    }

    measure: count_yo_momma {
        type: count
    }
}