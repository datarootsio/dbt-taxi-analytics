{{ config(
    materialized="view"
) }}

with -- !!!
    tripdata as (
        select *, row_number() over (partition by cast(vendorid as integer), tpep_pickup_datetime order by tpep_pickup_datetime) as rn
        from {{ source("staging", "yellow_2022") }}
        where vendorid is not null
    )
select
    -- identifiers
    {{ dbt_utils.generate_surrogate_key(["vendorid", "tpep_pickup_datetime"]) }}
    as tripid,
    cast(vendorid as integer) as vendorid,
    cast(ratecodeid as integer) as ratecodeid,
    cast(pulocationid as integer) as pickup_locationid,
    cast(dolocationid as integer) as dropoff_locationid,

    -- timestamps
    cast(tpep_pickup_datetime as timestamp) as pickup_datetime,
    cast(tpep_dropoff_datetime as timestamp) as dropoff_datetime,

    -- trip info
    cast(
        case when store_and_fwd_flag = 'Y' then true else false end as boolean
    ) as store_and_fwd_flag, -- Convertendo de String pra Boolean para ser mais performatico
    cast(passenger_count as integer) as passenger_count,
    cast(trip_distance as numeric) as trip_distance,
    -- yellow taxis são sempre "Street-hail" (não reservado e chamado na rua
    -- levantando a mão) -- 1 = Street-hail
    1 as trip_type,

    -- payment info
    cast(fare_amount as numeric) as fare_amount,
    cast(extra as numeric) as extra,
    cast(mta_tax as numeric) as mta_tax,
    cast(tip_amount as numeric) as tip_amount,
    cast(tolls_amount as numeric) as tolls_amount,
    -- "E-hail fee" = taxa cobrada quando solicita taxi por aplicativo. Yellow taxis
    -- não possuem.
    0 as ehail_fee,
    cast(abs(improvement_surcharge) as numeric) as improvement_surcharge,
    cast(total_amount as numeric) as total_amount,
    cast(payment_type as integer) as payment_type,
    {{ get_payment_type_description("payment_type") }} as payment_type_description,
    cast(abs(congestion_surcharge) as numeric) as congestion_surcharge,
    cast(abs(airport_fee) as numeric) as airport_fee
from tripdata
where rn = 1