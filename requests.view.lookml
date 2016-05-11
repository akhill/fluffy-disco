- view: requests
## This persistent derived table flattens out the 'request' table generated by data pass back end events.
## Note, user_id is not passed consistently in the request data pass event, thus the gnarly CASE statement to pull user_id from the "user" and "user_id" fields, whichever passes it correctly. This may be an expensive operation and is certainly worth revisiting...
## Also, we normalize the derived table to look at the last row in the scratch_beta.request table given we send a lot of data for the same request ID with data repopulation efforts...
## View is organized by: core request dimensions, request customer facts, request funnel dimension, etc...

  derived_table:
    sql_trigger_value: SELECT DATE_PART('hour', GETDATE()) ## hourly
    sortkeys: [id, user_id]
    distkey: id

    sql: |
      SELECT
        *
        , RANK() OVER(PARTITION BY user_id ORDER BY created ASC) AS request_index

          FROM
    
          (SELECT
            DISTINCT request_id AS id
            , FIRST_VALUE(user_id IGNORE NULLS) OVER (PARTITION BY request_id ORDER BY tstamp ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS user_id
            , FIRST_VALUE(created::timestamp IGNORE NULLS) OVER (PARTITION BY request_id ORDER BY tstamp ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS created
            , FIRST_VALUE(title IGNORE NULLS) OVER (PARTITION BY request_id ORDER BY tstamp ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS first_title
            , LAST_VALUE(title IGNORE NULLS) OVER (PARTITION BY request_id ORDER BY tstamp ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS current_title
            , FIRST_VALUE(description IGNORE NULLS) OVER (PARTITION BY request_id ORDER BY tstamp ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS first_description
            , LAST_VALUE(description IGNORE NULLS) OVER (PARTITION BY request_id ORDER BY tstamp ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS current_description
            , LAST_VALUE(modified::timestamp IGNORE NULLS) OVER (PARTITION BY request_id ORDER BY tstamp ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_modified
            , LAST_VALUE(next_action_date::timestamp IGNORE NULLS) OVER (PARTITION BY request_id ORDER BY tstamp ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS current_next_action_date
            , FIRST_VALUE(origin IGNORE NULLS) OVER (PARTITION BY request_id ORDER BY tstamp ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS origin
            , FIRST_VALUE(persona_id IGNORE NULLS) OVER (PARTITION BY request_id ORDER BY tstamp ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS first_persona_id
            , FIRST_VALUE(shopper_id IGNORE NULLS) OVER (PARTITION BY request_id ORDER BY tstamp ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS first_shopper_id
            , LAST_VALUE(shopper_id IGNORE NULLS) OVER (PARTITION BY request_id ORDER BY tstamp ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS current_shopper_id
            , INITCAP(LAST_VALUE(status IGNORE NULLS) OVER (PARTITION BY request_id ORDER BY tstamp ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)) AS current_status
            , FIRST_VALUE(type IGNORE NULLS) OVER (PARTITION BY request_id ORDER BY tstamp ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS category
            , INITCAP(LAST_VALUE(next_action IGNORE NULLS) OVER (PARTITION BY request_id ORDER BY tstamp ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)) AS current_next_action
            , FIRST_VALUE(priority IGNORE NULLS) OVER (PARTITION BY request_id ORDER BY tstamp ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS priority
            , INITCAP(LAST_VALUE(user_customer_score IGNORE NULLS) OVER (PARTITION BY request_id ORDER BY tstamp ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)) AS customer_score
            , LAST_VALUE(notes IGNORE NULLS) OVER (PARTITION BY request_id ORDER BY tstamp ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS notes
            , FIRST_VALUE(ip_country IGNORE NULLS) OVER (PARTITION BY request_id ORDER BY tstamp ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS ip_address_country_code
            , LAST_VALUE(experiment_id IGNORE NULLS) OVER (PARTITION BY request_id ORDER BY tstamp ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS experiment_id
            , LOWER(LAST_VALUE(experiment_result IGNORE NULLS) OVER (PARTITION BY request_id ORDER BY tstamp ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)) AS experiment_result
            , ROW_NUMBER() OVER(PARTITION BY request_id ORDER BY tstamp DESC) AS request_event_index_desc
            , FIRST_VALUE(ip IGNORE NULLS) OVER (PARTITION BY request_id ORDER BY tstamp ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS ip_address
    
          FROM
            public.t_request
            
          WHERE
            user_id NOT IN ('565613bc8419178d2bc5122f','5629b91f866fc7d6487ab4b4','5640edf3a44ffe12035ae2a6','5626553b13aab2d12cf4c7b0','562461cbd274fa4c0d14d92b','560fbfa44ac8cd7905a029ad','560eaf5e4ac8cd7905a028e2','55bc027db6c9a9457322b895','559abb739e73fa5631fdf0bc','55a3faf12620a21a0287bf29','559c83b14469543f1b534c3e','5581efab47319b4e70985261','559ac3cb4efd881c2a1de2a1','559c59c9c69c169d08f0dc1b','559e9a315a4668fb1108546e')
            AND request_id NOT IN ('570fcaf92bcea4513f631b92','570fcaf92bcea4513f631b89','570fcaf92bcea4513f631b93','570fcaf92bcea4513f631b8e','570fcaf92bcea4513f631b8f','570fcaf92bcea4513f631b8c','570fcaf92bcea4513f631b8d','570fcaf92bcea4513f631b90')
          )
          
          WHERE
            request_event_index_desc = 1

  fields:

# Dimensions #

  - dimension: id
    primary_key: true

  - dimension: user_id
    hidden:

  - dimension_group: created
    description: 'Request created timestamp'
    type: time
    timeframes: [time, date, week, month, quarter, hour_of_day, day_of_week]

  - dimension: first_title
    description: 'First title taken from first request chat item or collection item'

  - dimension: current_title
    description: 'Most recent title as updated by ShopOps'

  - dimension: first_description
    description: 'First description as taken from request chat item'

  - dimension: current_description
    description: 'Most recent description as updated by ShopOps'

  - dimension_group: last_modified
    description: 'Last time request was touched by either customer, shopper or scratchbot, i.e. the last time its status changed'
    type: time
    timeframes: [time, date, week, month, hour_of_day, day_of_week]

  - dimension_group: current_next_action_date
    description: 'For shoppers: what is the current next action date in shopper interface'
    type: time
    timeframes: [time, date, week, month, hour_of_day, day_of_week]

  - dimension: origin
    description: 'As categorized by our app'

  - dimension: category
    description: 'As categorized by our app'

  - dimension: request_created_after_012216_feedback_mechanism
    description: 'Yes is request created after feedback mechanism. No if before'
    type: yesno
    sql: ${created_date} > '2016-01-22'

  - dimension: first_persona_id
    description: 'Persona associated with first chat item customer saw'

  - dimension: first_shopper_id
    description: 'First shopper assigned to request'

  - dimension: current_shopper_id
    description: 'Last shopper assigned to request'

  - dimension: current_status
    description: 'Archived or Active, as set in Shopper Interface'

  - dimension: current_next_action
    description: 'None, Need_Info, Follow_up, Recos_Sent, Ditched, NULL, Needs_Review, Order, Shop as set in Shopper Interface'

  - dimension: priority
    description: 'As set in Shopper Interface'

  - dimension: customer_score
    description: 'As set in Shopper Interface'

  - dimension: notes
    description: 'As set in Shopper Interface'
    
  - dimension: curated_learning_test_condition
    description: 'Part of mom birthday or boyfriend test starting Apr 7' 
    sql_case: 
      Test: lower(${notes}) like '%banana%'
      Exception: lower(${notes}) like '%apple%'
      else: 'Blank'
    
  - dimension: request_index
    description: '1 = customers 1st request. 2 = 2nd request, etc...'
    type: number

  - dimension: request_index_tier
    description: '1 = customers 1st request. 2 = 2nd request, etc...'
    type: tier
    style: integer
    tiers: [1,2,3,5,10,12,15,20]
    sql: ${request_index}

  - dimension: request_link
    description: 'Link to request in shopper interface'
    sql: ${id}
    html: |
      <a href="https://si.helloshopper.com/request/{{value}}" " target="_blank">Shopper interface link</a>

  - dimension: message_stream
    description: 'Explore that summarizes all messages related to a request'
    sql: ${id}
    html: |
      <a href=messages?fields=requests.message_stream*&f[requests.id]={{value}}>Message Stream</a>

  - dimension: experiment_id
    description: 'Code-driven (i.e. recogen) experiment IDs'

  - dimension: experiment_name
    description: 'Version of experiment'
    sql: |
      CASE
        WHEN ${experiment_id} = '57116927050903484ab0335c' THEN 'mothers day v1'
        WHEN ${experiment_id} = '571fb7a8467a42a459070bce' THEN 'mothers day v2'
        WHEN ${experiment_id} = '57236dfb1f583c6861f60f68' THEN 'husbafriend v1'
        WHEN ${experiment_id} = '5728d8e5f7cba9dfab50b183' THEN 'husbafriend v2'
        WHEN ${experiment_id} = '572b89b45cc8452c1462bf47' THEN 'seemore'
        WHEN ${experiment_id} = '572ba8792ff16cf45aa0f6fc' THEN '15-plus'
        ELSE 'unknown'
      END

  - dimension: experiment_result
    description: 'Value representing whether/how experiment ran'
    type: string

#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Request customer facts #

  - dimension: ip_address_country_code
  
  - dimension: internal_ip_addresses
    type: yesno
    sql: ${TABLE}.ip_address IN ('96.89.239.217', '146.115.135.104', '174.63.120.5', '73.69.146.33', '66.30.112.58', '65.96.147.123', '108.15.29.191', '73.186.245.146', '65.96.65.176', '172.85.61.20', '80.4.63.186', '63.141.194.202', '50.137.111.172', '209.6.94.47', '209.6.197.82', '50.138.140.66', '65.27.187.73', '97.116.172.110')

#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Aggregate measures #

  - measure: count
    type: count
    drill_fields: detail*
    
  - measure: percent_of_total
    type: percent_of_total
    sql: ${count}
  
  - measure: count_customers
    type: count_distinct
    sql: ${user_id}
    drill_fields: customer_detail*


#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Request funnel dimensions #

    
#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Request funnel - aggregate counts #



#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Request funnel - percentages ##


#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Time-based dimensions related to Shop Ops KPIs #


#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Time-based ShopOps KPIs ##



#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    
  sets:
    detail:
      - created_time
      - id
      - customers.full_name
      - current_title
      - has_recommendations
      - has_auto_generated_recommendations
      - experiment_name
      - experiment_release
      - experiment_result
      - request_message_facts.occasion
      - request_message_facts.for_whom
      - request_message_facts.age
      - request_message_facts.budget
      - request_message_facts.additional_details
      - has_converted
      - request_order_facts.first_order_created_time
      - customer_request_facts.lifetime_requests
      - customer_request_facts.lifetime_conversions
      - message_stream
      - customers.request_history
      - source
      - request_link
      - user_id
    conversion_detail:
      - customers.full_name
      - customers.user_id
      - current_title
      - category_grouped
      - created_time
      - request_message_facts.first_recommendation_time
      - request_order_facts.first_order_created_time
      - request_message_facts.customer_request_flow_response_string_length
      - customer_request_facts.lifetime_orders
      - customer_session_facts.first_session_utm_medium
      - customer_session_facts.first_session_utm_source
      - customer_session_facts.first_session_utm_campaign
      - customer_session_facts.lifetime_session_history
      - customer_session_facts.lifetime_event_history
      - id
    customer_detail:
      - customers.full_name
      - customers.email
      - customers.customer_score
      - customer_request_facts.lifetime_gross_revenue
      - customer_request_facts.trailing_90_day_purchase_bucket
      - customer_request_facts.last_request_created_date
      - customer_request_facts.lifetime_requests
      - customer_request_facts.last_order_created_date
      - customer_request_facts.lifetime_orders
      - customer_session_facts.number_of_sessions_tiered
      - customer_session_facts.last_session_start
      - customer_session_facts.has_used_mobile_app
      - customers.account_sign_up_date
      - customer_session_facts.request_created_in_first_auth_session
      - customer_session_facts.first_session_with_request
      - customer_session_facts.first_session_utm_medium
      - customer_session_facts.first_session_utm_source
      - customer_session_facts.first_session_utm_campaign
      - customers.notes
      - customers.user_id
      - customer_session_facts.lifetime_session_history
      - customer_session_facts.lifetime_event_history
    message_stream:
      - messages.created_time
      - messages.type
      - title
      - messages.message_index
      - messages.sender_type
      - messages.message_type
      - messages.message
      - recommendations.product_brand
      - recommendations.product_name
      - recommendations.product_price
      - messages.message_text
      - request_link
    request_history:
      - request_index
      - created_time
      - current_title
      - category_grouped
      - request_message_facts.number_of_shopper_messages
      - request_message_facts.number_of_customer_non_auto_chat_reply_messages
      - has_recommendations
      - has_converted
      - orders.total_price
      - request_link
      - id
    recommendation_detail:
      - recommendation_id
      - requests.request_link
      - requests.title
      - created_time
      - products.name
      - products.created_time
      - product_recommended_from_catalog
      - product_recommended_from_internet
