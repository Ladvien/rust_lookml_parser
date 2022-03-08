include: "dq_constants.view.lkml"
view: dq_client_program_demographics {

    dimension: yomomma {
        sql: ${TABLE}.duh ;;
    }

    measure: count_yo_momma {
        type: count
    }
}