require "./resource"
require "./duration"

module Google::Maps
  module RouteOptimization
    struct OptimizeToursRequest
      include Resource

      # If this timeout is set, the server returns a response before the timeout
      # period has elapsed or the server deadline for synchronous requests is
      # reached, whichever is sooner.
      #
      # For asynchronous requests, the server will generate a solution (if
      # possible) before the timeout has elapsed.
      @[JSON::Field(converter: Google::Duration)]
      field timeout : Time::Span

      # Shipment model to solve.
      field model : ShipmentModel

      # By default, the solving mode is `SolvingMode::DEFAULT_SOLVE`.
      field solving_mode : SolvingMode = :default_solve

      # Search mode used to solve the request.
      field search_mode : SearchMode = :search_mode_unspecified

      # Guide the optimization algorithm in finding a first solution that is similar to a previous solution.
      #
      # The model is constrained when the first solution is built. Any shipments not performed on a route are implicitly skipped in the first solution, but they may be performed in successive solutions.
      #
      # The solution must satisfy some basic validity assumptions:
      #
      # - for all routes, vehicleIndex must be in range and not be duplicated.
      # - for all visits, shipmentIndex and visitRequestIndex must be in range.
      # - a shipment may only be referenced on one route.
      # - the pickup of a pickup-delivery shipment must be performed before the delivery.
      # - no more than one pickup alternative or delivery alternative of a shipment may be performed.
      # - for all routes, times are increasing (i.e., vehicleStartTime <= visits[0].start_time <= visits[1].start_time ... <= vehicleEndTime).
      # - a shipment may only be performed on a vehicle that is allowed. A vehicle is allowed if Shipment.allowed_vehicle_indices is empty or its vehicleIndex is included in Shipment.allowed_vehicle_indices.
      #
      # If the injected solution is not feasible, a validation error is not necessarily returned and an error indicating infeasibility may be returned instead.
      field injected_first_solution_routes : Array(ShipmentRoute)

      # Constrain the optimization algorithm to find a final solution that is similar to a previous solution. For example, this may be used to freeze portions of routes which have already been completed or which are to be completed but must not be modified.
      #
      # If the injected solution is not feasible, a validation error is not necessarily returned and an error indicating infeasibility may be returned instead.
      field injected_solution_constraint : InjectedSolutionConstraint?

      # If non-empty, the given routes will be refreshed, without modifying their underlying sequence of visits or travel times: only other details will be updated. This does not solve the model.
      #
      # As of 2020/11, this only populates the polylines of non-empty routes and requires that populatePolylines is true.
      #
      # The routePolyline fields of the passed-in routes may be inconsistent with route transitions.
      #
      # This field must not be used together with injectedFirstSolutionRoutes or injectedSolutionConstraint.
      #
      # Shipment.ignore and Vehicle.ignore have no effect on the behavior. Polylines are still populated between all visits in all non-empty routes regardless of whether the related shipments or vehicles are ignored.
      field refresh_details_routes : Array(ShipmentRoute)

      # If true:
      #
      # - uses ShipmentRoute.vehicle_label instead of vehicleIndex to match routes in an injected solution with vehicles in the request; reuses the mapping of original ShipmentRoute.vehicle_index to new ShipmentRoute.vehicle_index to update ConstraintRelaxation.vehicle_indices if non-empty, but the mapping must be unambiguous (i.e., multiple ShipmentRoutes must not share the same original vehicleIndex).
      # - uses ShipmentRoute.Visit.shipment_label instead of shipmentIndex to match visits in an injected solution with shipments in the request;
      # - uses SkippedShipment.label instead of SkippedShipment.index to match skipped shipments in the injected solution with request shipments.
      #
      # This interpretation applies to the injectedFirstSolutionRoutes, injectedSolutionConstraint, and refreshDetailsRoutes fields. It can be used when shipment or vehicle indices in the request have changed since the solution was created, perhaps because shipments or vehicles have been removed from or added to the request.
      #
      # If true, labels in the following categories must appear at most once in their category:
      #
      # - Vehicle.label in the request;
      # - Shipment.label in the request;
      # - ShipmentRoute.vehicle_label in the injected solution;
      # - SkippedShipment.label and ShipmentRoute.Visit.shipment_label in the injected solution (except pickup/delivery visit pairs, whose shipmentLabel must appear twice).
      #
      # If a vehicleLabel in the injected solution does not correspond to a request vehicle, the corresponding route is removed from the solution along with its visits. If a shipmentLabel in the injected solution does not correspond to a request shipment, the corresponding visit is removed from the solution. If a SkippedShipment.label in the injected solution does not correspond to a request shipment, the SkippedShipment is removed from the solution.
      #
      # Removing route visits or entire routes from an injected solution may have an effect on the implied constraints, which may lead to change in solution, validation errors, or infeasibility.
      #
      # NOTE: The caller must ensure that each Vehicle.label (resp. Shipment.label) uniquely identifies a vehicle (resp. shipment) entity used across the two relevant requests: the past request that produced the OptimizeToursResponse used in the injected solution and the current request that includes the injected solution. The uniqueness checks described above are not enough to guarantee this requirement.
      field interpret_injected_solutions_using_labels : Bool

      # Consider traffic estimation in calculating ShipmentRoute fields Transition.travel_duration, Visit.start_time, and vehicleEndTime; in setting the ShipmentRoute.has_traffic_infeasibilities field, and in calculating the OptimizeToursResponse.total_cost field.
      field? consider_road_traffic : Bool

      # If true, polylines will be populated in response ShipmentRoutes.
      field? populate_polylines : Bool

      # If true, polylines and route tokens will be populated in response ShipmentRoute.transitions.
      field? populate_transition_polylines : Bool

      # If this is set, then the request can have a deadline (see https://grpc.io/blog/deadlines) of up to 60 minutes. Otherwise, the maximum deadline is only 30 minutes. Note that long-lived requests have a significantly larger (but still small) risk of interruption.
      field? allow_large_deadline_despite_interruption_risk : Bool

      # If true, travel distances will be computed using geodesic distances instead of Google Maps distances, and travel times will be computed using geodesic distances with a speed defined by geodesicMetersPerSecond.
      field? use_geodesic_distances : Bool

      # Label that may be used to identify this request, reported back in the OptimizeToursResponse.request_label.
      field label : String

      # When useGeodesicDistances is true, this field must be set and defines the speed applied to compute travel times. Its value must be at least 1.0 meters/seconds.
      field geodesic_meters_per_second : Float64

      # Truncates the number of validation errors returned. These errors are typically attached to an INVALID_ARGUMENT error payload as a BadRequest error detail (https://cloud.google.com/apis/design/errors#error_details), unless solvingMode=VALIDATE_ONLY: see the OptimizeToursResponse.validation_errors field. This defaults to 100 and is capped at 10,000.
      field max_validation_errors : Int32
    end

    struct OptimizeToursResponse
      include Resource

      # Routes computed for each vehicle; the i-th route corresponds to the i-th vehicle in the model.
      field routes : Array(ShipmentRoute)

      # Copy of the `OptimizeToursRequest#label,` if a label was specified in the request.
      field request_label : String?

      # The list of all shipments skipped.
      field skipped_shipments : Array(SkippedShipment)

      # List of all the validation errors that we were able to detect independently. See the "MULTIPLE ERRORS" explanation for the OptimizeToursValidationError message. Instead of errors, this will include warnings in the case solvingMode is DEFAULT_SOLVE.
      field validation_errors : Array(OptimizeToursValidationError)

      # Duration, distance and usage metrics for this solution.
      field metrics : Metrics
    end

    # Describes an error or warning encountered when validating an OptimizeToursRequest
    struct OptimizeToursValidationError
      include Resource

      # A validation error is defined by the pair (code, displayName) which are always present
      field code : Int32

      # The error display name
      field display_name : String

      # Context fields for the error
      field fields : Array(FieldReference)

      # Human-readable string describing the error
      field error_message : String

      # May contain the value(s) of the field(s). This is not always available.
      # Use only for manual model debugging.
      field offending_values : String?
    end

    # Specifies a context for the validation error
    struct FieldReference
      include Resource

      # Name of the field, e.g., "vehicles"
      field name : String

      # Recursively nested sub-field, if needed
      field sub_field : FieldReference?

      # Index of the field if repeated
      field index : Int32?

      # Key if the field is a map
      field key : String?
    end

    struct ShipmentModel
      include Resource

      # Set of shipments which must be performed in the model.
      field shipments : Array(Shipment)

      # Set of vehicles which can be used to perform visits.
      field vehicles : Array(Vehicle)

      # Global start and end time of the model: no times outside of this range can be considered valid.
      #
      # The model's time span must be less than a year, i.e. the globalEndTime and the globalStartTime must be within 31536000 seconds of each other.
      #
      # When using cost_per_*hour fields, you might want to set this window to a smaller interval to increase performance (eg. if you model a single day, you should set the global time limits to that day). If unset, 00:00:00 UTC, January 1, 1970 (i.e. seconds: 0, nanos: 0) is used as default.
      field global_start_time : Time

      # If unset, 00:00:00 UTC, January 1, 1971 (i.e. seconds: 31536000, nanos: 0) is used as default.
      field global_end_time : Time

      # The "global duration" of the overall plan is the difference between the earliest effective start time and the latest effective end time of all vehicles. Users can assign a cost per hour to that quantity to try and optimize for earliest job completion, for example. This cost must be in the same unit as Shipment.penalty_cost.
      field global_duration_cost_per_hour : Float64

      # Specifies duration and distance matrices used in the model. If this field is empty, Google Maps or geodesic distances will be used instead, depending on the value of the useGeodesicDistances field. If it is not empty, useGeodesicDistances cannot be true and neither durationDistanceMatrixSrcTags nor durationDistanceMatrixDstTags can be empty.
      #
      # Usage examples:
      #
      # - There are two locations: locA and locB.
      # - 1 vehicle starting its route at locA and ending it at locA.
      # - 1 pickup visit request at locB.
      #
      # model {
      #   vehicles { startTags: "locA"  endTags: "locA" }
      #   shipments { pickups { tags: "locB" } }
      #   durationDistanceMatrixSrcTags: "locA"
      #   durationDistanceMatrixSrcTags: "locB"
      #   durationDistanceMatrixDstTags: "locA"
      #   durationDistanceMatrixDstTags: "locB"
      #   durationDistanceMatrices {
      #     rows {  # from: locA
      #       durations { seconds: 0 }   meters: 0    # to: locA
      #       durations { seconds: 100 } meters: 1000 # to: locB
      #     }
      #     rows {  # from: locB
      #       durations { seconds: 102 } meters: 990 # to: locA
      #       durations { seconds: 0 }   meters: 0   # to: locB
      #     }
      #   }
      # }
      # There are three locations: locA, locB and locC.
      # - 1 vehicle starting its route at locA and ending it at locB, using matrix "fast".
      # - 1 vehicle starting its route at locB and ending it at locB, using matrix "slow".
      # - 1 vehicle starting its route at locB and ending it at locB, using matrix "fast".
      # - 1 pickup visit request at locC.
      #
      # model {
      #   vehicles { startTags: "locA" endTags: "locB" startTags: "fast" }
      #   vehicles { startTags: "locB" endTags: "locB" startTags: "slow" }
      #   vehicles { startTags: "locB" endTags: "locB" startTags: "fast" }
      #   shipments { pickups { tags: "locC" } }
      #   durationDistanceMatrixSrcTags: "locA"
      #   durationDistanceMatrixSrcTags: "locB"
      #   durationDistanceMatrixSrcTags: "locC"
      #   durationDistanceMatrixDstTags: "locB"
      #   durationDistanceMatrixDstTags: "locC"
      #   durationDistanceMatrices {
      #     vehicleStartTag: "fast"
      #     rows {  # from: locA
      #       durations { seconds: 1000 } meters: 2000 # to: locB
      #       durations { seconds: 600 }  meters: 1000 # to: locC
      #     }
      #     rows {  # from: locB
      #       durations { seconds: 0 }   meters: 0    # to: locB
      #       durations { seconds: 700 } meters: 1200 # to: locC
      #     }
      #     rows {  # from: locC
      #       durations { seconds: 702 } meters: 1190 # to: locB
      #       durations { seconds: 0 }   meters: 0    # to: locC
      #     }
      #   }
      #   durationDistanceMatrices {
      #     vehicleStartTag: "slow"
      #     rows {  # from: locA
      #       durations { seconds: 1800 } meters: 2001 # to: locB
      #       durations { seconds: 900 }  meters: 1002 # to: locC
      #     }
      #     rows {  # from: locB
      #       durations { seconds: 0 }    meters: 0    # to: locB
      #       durations { seconds: 1000 } meters: 1202 # to: locC
      #     }
      #     rows {  # from: locC
      #       durations { seconds: 1001 } meters: 1195 # to: locB
      #       durations { seconds: 0 }    meters: 0    # to: locC
      #     }
      #   }
      # }
      field duration_distance_matrices : Array(DurationDistanceMatrix)

      # Tags defining the sources of the duration and distance matrices; durationDistanceMatrices(i).rows(j) defines durations and distances from visits with tag durationDistanceMatrixSrcTags(j) to other visits in matrix i.
      #
      # Tags correspond to VisitRequest.tags or Vehicle.start_tags. A given VisitRequest or Vehicle must match exactly one tag in this field. Note that a Vehicle's source, destination and matrix tags may be the same; similarly a VisitRequest's source and destination tags may be the same. All tags must be different and cannot be empty strings. If this field is not empty, then durationDistanceMatrices must not be empty.
      field durationDistanceMatrixSrcTags : Array(String)

      # Tags defining the destinations of the duration and distance matrices; durationDistanceMatrices(i).rows(j).durations(k) (resp. durationDistanceMatrices(i).rows(j).meters(k)) defines the duration (resp. the distance) of the travel from visits with tag durationDistanceMatrixSrcTags(j) to visits with tag durationDistanceMatrixDstTags(k) in matrix i.
      #
      # Tags correspond to VisitRequest.tags or Vehicle.start_tags. A given VisitRequest or Vehicle must match exactly one tag in this field. Note that a Vehicle's source, destination and matrix tags may be the same; similarly a VisitRequest's source and destination tags may be the same. All tags must be different and cannot be empty strings. If this field is not empty, then durationDistanceMatrices must not be empty.
      field durationDistanceMatrixDstTags : Array(String)

      # Transition attributes added to the model.
      field transition_attributes : Array(TransitionAttributes)

      # Sets of incompatible shipment_types (see ShipmentTypeIncompatibility).
      field shipment_type_incompatibilities : Array(ShipmentTypeIncompatibility)

      # Sets of shipmentType requirements (see ShipmentTypeRequirement).
      field shipment_type_requirements : Array(ShipmentTypeRequirement)

      # Set of precedence rules which must be enforced in the model.
      field precedence_rules : Array(PrecedenceRule)

      # Constrains the maximum number of active vehicles. A vehicle is active if its route performs at least one shipment. This can be used to limit the number of routes in the case where there are fewer drivers than vehicles and that the fleet of vehicles is heterogeneous. The optimization will then select the best subset of vehicles to use. Must be strictly positive.
      field max_active_vehicles : Int64
    end

    # Represents a latitude/longitude pair using WGS84 standard
    struct LatLng
      include Resource

      # Must be in range [-90.0, +90.0]
      field latitude : Float64

      # Must be in range [-180.0, +180.0]
      field longitude : Float64
    end

    # Encapsulates a waypoint for visit locations and vehicle start/end points
    struct Waypoint
      include Resource

      # Indicates preference for vehicle to stop at particular side of road
      field side_of_road : Bool?

      # A point specified using geographic coordinates
      field location : Location?

      # The POI Place ID associated with the waypoint
      field place_id : String?
    end

    # Encapsulates a location with coordinates and optional heading
    struct Location
      include Resource

      # The waypoint's geographic coordinates
      field lat_lng : LatLng

      # Compass heading (0-360, where 0 is North)
      field heading : Int32?
    end

    # Time windows constrain the time of an event
    struct TimeWindow
      include Resource

      # The hard time window start time
      field start_time : Time

      # The hard time window end time
      field end_time : Time

      # The soft start time of the time window
      field soft_start_time : Time?

      # The soft end time of the time window
      field soft_end_time : Time?

      # Cost per hour added if event occurs before soft_start_time
      field cost_per_hour_before_soft_start_time : Float64?

      # Cost per hour added if event occurs after soft_end_time
      field cost_per_hour_after_soft_end_time : Float64?
    end

    # Travel modes for vehicles
    enum TravelMode
      TRAVEL_MODE_UNSPECIFIED # Equivalent to DRIVING
      DRIVING                 # Car driving directions
      WALKING                 # Walking directions
    end

    # Route modifiers affecting road usage and vehicle speed
    struct RouteModifiers
      include Resource

      # Whether to avoid toll roads
      field avoid_tolls : Bool?

      # Whether to avoid highways
      field avoid_highways : Bool?

      # Whether to avoid ferries
      field avoid_ferries : Bool?

      # Whether to avoid indoor navigation (WALKING only)
      field avoid_indoor : Bool?
    end

    # Policy for how a vehicle can be unloaded
    enum UnloadingPolicy
      UNLOADING_POLICY_UNSPECIFIED # Deliveries after pickups
      LAST_IN_FIRST_OUT            # Reverse order of pickups
      FIRST_IN_FIRST_OUT           # Same order as pickups
    end

    # Defines a load limit applying to a vehicle
    struct LoadLimit
      include Resource

      # A soft limit of the load
      field soft_max_load : Int64?

      # Cost per unit when load exceeds soft_max_load
      field cost_per_unit_above_soft_max : Float64?

      # Acceptable load interval at start of route
      field start_load_interval : Interval?

      # Acceptable load interval at end of route
      field end_load_interval : Interval?

      # Maximum acceptable amount of load
      field max_load : Int64?
    end

    # Interval of acceptable load amounts
    struct Interval
      include Resource

      # Minimum acceptable load, must be >= 0
      field min : Int64?

      # Maximum acceptable load, must be >= 0
      field max : Int64?
    end

    # Duration limit configuration
    struct DurationLimit
      include Resource

      # Hard maximum duration limit
      field max_duration : String?

      # Soft maximum duration with associated cost
      field soft_max_duration : String?

      # Soft max for quadratic cost increase
      field quadratic_soft_max_duration : String?

      # Cost per hour over soft max
      field cost_per_hour_after_soft_max : Float64?

      # Cost per square hour over quadratic soft max
      field cost_per_square_hour_after_quadratic_soft_max : Float64?
    end

    # Distance limit configuration
    struct DistanceLimit
      include Resource

      # Hard maximum distance in meters
      field max_meters : Int64?

      # Soft maximum distance in meters
      field soft_max_meters : Int64?

      # Cost per km under soft max
      field cost_per_kilometer_below_soft_max : Float64?

      # Cost per km over soft max
      field cost_per_kilometer_above_soft_max : Float64?
    end

    # Rules for generating vehicle breaks
    struct BreakRule
      include Resource

      # Sequence of breaks
      field break_requests : Array(BreakRequest)

      # Time constraints between breaks
      field frequency_constraints : Array(FrequencyConstraint)
    end

    # Defines a required break period
    struct BreakRequest
      include Resource

      # Lower bound on break start time
      field earliest_start_time : Time

      # Upper bound on break start time
      field latest_start_time : Time

      # Minimum duration of the break
      field min_duration : String
    end

    # Frequency requirements for breaks
    struct FrequencyConstraint
      include Resource

      # Minimum duration of break that satisfies this constraint
      field min_break_duration : String

      # Maximum duration between qualifying breaks
      field max_inter_break_duration : String
    end

    # Duration and distance matrix configuration
    struct DurationDistanceMatrix
      include Resource

      # Matrix rows defining durations/distances
      field rows : Array(Row)

      # Which vehicles this matrix applies to
      field vehicle_start_tag : String?
    end

    # Single row of duration/distance matrix
    struct Row
      include Resource

      # Travel durations for destinations
      field durations : Array(String)

      # Travel distances in meters
      field meters : Array(Float64)
    end

    # Attributes for transitions between visits
    struct TransitionAttributes
      include Resource

      # Source visit/vehicle tag
      field src_tag : String?

      # Excluded source tag
      field excluded_src_tag : String?

      # Destination visit/vehicle tag
      field dst_tag : String?

      # Excluded destination tag
      field excluded_dst_tag : String?

      # Fixed cost for this transition
      field cost : Float64?

      # Cost per km for this transition
      field cost_per_kilometer : Float64?

      # Distance limits for this transition
      field distance_limit : DistanceLimit?

      # Required delay duration
      field delay : String?
    end

    # Incompatibility rules between shipment types
    struct ShipmentTypeIncompatibility
      include Resource

      # List of incompatible shipment types
      field types : Array(String)

      # How incompatibility is enforced
      field incompatibility_mode : IncompatibilityMode
    end

    # Incompatibility enforcement modes
    enum IncompatibilityMode
      INCOMPATIBILITY_MODE_UNSPECIFIED
      NOT_PERFORMED_BY_SAME_VEHICLE      # Cannot share vehicle
      NOT_IN_SAME_VEHICLE_SIMULTANEOUSLY # Cannot overlap in vehicle
    end

    # Requirements between shipment types
    struct ShipmentTypeRequirement
      include Resource

      # Types that can satisfy requirement
      field required_shipment_type_alternatives : Array(String)

      # Types that need requirement satisfied
      field dependent_shipment_types : Array(String)

      # How requirement is enforced
      field requirement_mode : RequirementMode
    end

    # Requirement enforcement modes
    enum RequirementMode
      REQUIREMENT_MODE_UNSPECIFIED
      PERFORMED_BY_SAME_VEHICLE        # Must share vehicle
      IN_SAME_VEHICLE_AT_PICKUP_TIME   # Required at pickup
      IN_SAME_VEHICLE_AT_DELIVERY_TIME # Required at delivery
    end

    # Visit request for pickup or delivery of a shipment
    struct VisitRequest
      include Resource

      # The geo-location where the vehicle arrives
      field arrival_location : LatLng?

      # The waypoint where vehicle arrives
      field arrival_waypoint : Waypoint?

      # The geo-location where the vehicle departs from
      field departure_location : LatLng?

      # The waypoint where vehicle departs from
      field departure_waypoint : Waypoint?

      # Tags attached to the visit request
      field tags : Array(String)

      # Time windows constraining arrival time
      field time_windows : Array(TimeWindow)

      # Duration of the visit
      field duration : String

      # Cost to service this visit request
      field cost : Float64?

      # Load demands specific to this visit
      field load_demands : Hash(String, Load)

      # Types of the visit for scheduling purposes
      field visit_types : Array(String)

      # Label for this visit request
      field label : String?
    end

    # Single item shipment from pickup(s) to delivery(s)
    struct Shipment
      include Resource

      # Display name (up to 63 UTF-8 chars)
      field display_name : String?

      # Set of available pickup locations
      field pickups : Array(VisitRequest)

      # Set of available delivery locations
      field deliveries : Array(VisitRequest)

      # Load demands of the shipment
      field load_demands : Hash(String, Load)

      # Vehicles that may perform this shipment
      field allowed_vehicle_indices : Array(Int32)

      # Cost per vehicle to perform shipment
      field costs_per_vehicle : Array(Float64)

      # Indices that costs_per_vehicle applies to
      field costs_per_vehicle_indices : Array(Int32)

      # Maximum absolute detour time
      field pickup_to_delivery_absolute_detour_limit : String?

      # Maximum time between pickup and delivery
      field pickup_to_delivery_time_limit : String?

      # Type classification for this shipment
      field shipment_type : String?

      # Label for this shipment
      field label : String?

      # Whether to skip this shipment
      field ignore : Bool?

      # Cost if shipment is not completed
      field penalty_cost : Float64?

      # Maximum relative detour time
      field pickup_to_delivery_relative_detour_limit : Float64?
    end

    struct Load
      include Resource

      # The amount by which the load of the vehicle performing the corresponding visit will vary. Since it is an integer, users are advised to choose an appropriate unit to avoid loss of precision. Must be ≥ 0.
      field amount : String
    end

    struct VehicleLoad
      include Resource

      # The amount of load on the vehicle, for the given type. The unit of load is usually indicated by the type. See Transition.vehicle_loads.
      field amount : String
    end

    # Aggregated metrics for routes and solutions
    struct AggregatedMetrics
      include Resource

      # Number of shipments performed (pickup + delivery = 1)
      field performed_shipment_count : Int32

      # Total travel duration
      field travel_duration : String

      # Total wait duration
      field wait_duration : String

      # Total delay duration
      field delay_duration : String

      # Total break duration
      field break_duration : String

      # Total visit duration
      field visit_duration : String

      # Total duration (sum of all durations)
      field total_duration : String

      # Total travel distance in meters
      field travel_distance_meters : Float64

      # Maximum load achieved per quantity type
      field max_loads : Hash(String, VehicleLoad)
    end

    # Vehicle that can perform shipments in a route
    struct Vehicle
      include Resource

      # Display name (up to 63 UTF-8 chars)
      field display_name : String?

      # Travel mode affecting roads and speed
      field travel_mode : TravelMode

      # Route calculation conditions
      field route_modifiers : RouteModifiers?

      # Starting location for the route
      field start_location : LatLng?

      # Starting waypoint for the route
      field start_waypoint : Waypoint?

      # Ending location for the route
      field end_location : LatLng?

      # Ending waypoint for the route
      field end_waypoint : Waypoint?

      # Tags for the route start
      field start_tags : Array(String)

      # Tags for the route end
      field end_tags : Array(String)

      # Time windows for departure
      field start_time_windows : Array(TimeWindow)

      # Time windows for arrival
      field end_time_windows : Array(TimeWindow)

      # Rules for unloading order
      field unloading_policy : UnloadingPolicy

      # Vehicle capacity limits
      field load_limits : Hash(String, LoadLimit)

      # Cost per hour of operation
      field cost_per_hour : Float64?

      # Cost per hour of travel time
      field cost_per_traveled_hour : Float64?

      # Cost per kilometer traveled
      field cost_per_kilometer : Float64?

      # Fixed cost if vehicle is used
      field fixed_cost : Float64?

      # Whether counted as used when empty
      field used_if_route_is_empty : Bool?

      # Total route duration limits
      field route_duration_limit : DurationLimit?

      # Travel time duration limits
      field travel_duration_limit : DurationLimit?

      # Total distance limits
      field route_distance_limit : DistanceLimit?

      # Extra time per visit type
      field extra_visit_duration_for_visit_type : Hash(String, String)

      # Required break schedule
      field break_rule : BreakRule?

      # Label for this vehicle
      field label : String?

      # Whether to skip this vehicle
      field ignore : Bool?

      # Travel time multiplier
      field travel_duration_multiple : Float64?
    end

    # Precedence rules between shipment events
    struct PrecedenceRule
      include Resource

      # Whether first event is delivery
      field first_is_delivery : Bool

      # Whether second event is delivery
      field second_is_delivery : Bool

      # Required time offset between events
      field offset_duration : String

      # Index of first shipment
      field first_index : Int32

      # Index of second shipment
      field second_index : Int32
    end

    # A vehicle's route can be decomposed, along the time axis, like this (we assume there are n visits):
    #
    #   |            |            |          |       |  T[2], |        |      |
    #   | Transition |  Visit #0  |          |       |  V[2], |        |      |
    #   |     #0     |    aka     |   T[1]   |  V[1] |  ...   | V[n-1] | T[n] |
    #   |  aka T[0]  |    V[0]    |          |       | V[n-2],|        |      |
    #   |            |            |          |       | T[n-1] |        |      |
    #   ^            ^            ^          ^       ^        ^        ^      ^
    # vehicle    V[0].start   V[0].end     V[1].   V[1].    V[n].    V[n]. vehicle
    #  start     (arrival)   (departure)   start   end      start    end     end
    # Note that we make a difference between:
    #
    # "punctual events", such as the vehicle start and end and each visit's start and end (aka arrival and departure). They happen at a given second.
    # "time intervals", such as the visits themselves, and the transition between visits. Though time intervals can sometimes have zero duration, i.e. start and end at the same second, they often have a positive duration.
    # Invariants:
    #
    # If there are n visits, there are n+1 transitions.
    # A visit is always surrounded by a transition before it (same index) and a transition after it (index + 1).
    # The vehicle start is always followed by transition #0.
    # The vehicle end is always preceded by transition #n.
    # Zooming in, here is what happens during a Transition and a Visit:
    #
    # ---+-------------------------------------+-----------------------------+-->
    #    |           TRANSITION[i]             |           VISIT[i]          |
    #    |                                     |                             |
    #    |  * TRAVEL: the vehicle moves from   |      PERFORM the visit:     |
    #    |    VISIT[i-1].departure_location to |                             |
    #    |    VISIT[i].arrival_location, which |  * Spend some time:         |
    #    |    takes a given travel duration    |    the "visit duration".    |
    #    |    and distance                     |                             |
    #    |                                     |  * Load or unload           |
    #    |  * BREAKS: the driver may have      |    some quantities from the |
    #    |    breaks (e.g. lunch break).       |    vehicle: the "demand".   |
    #    |                                     |                             |
    #    |  * WAIT: the driver/vehicle does    |                             |
    #    |    nothing. This can happen for     |                             |
    #    |    many reasons, for example when   |                             |
    #    |    the vehicle reaches the next     |                             |
    #    |    event's destination before the   |                             |
    #    |    start of its time window         |                             |
    #    |                                     |                             |
    #    |  * DELAY: *right before* the next   |                             |
    #    |    arrival. E.g. the vehicle and/or |                             |
    #    |    driver spends time unloading.    |                             |
    #    |                                     |                             |
    # ---+-------------------------------------+-----------------------------+-->
    #    ^                                     ^                             ^
    # V[i-1].end                           V[i].start                    V[i].end
    # Lastly, here is how the TRAVEL, BREAKS, DELAY and WAIT can be arranged during a transition.

    # They don't overlap.
    # The DELAY is unique and must be a contiguous period of time right before the next visit (or vehicle end). Thus, it suffice to know the delay duration to know its start and end time.
    # The BREAKS are contiguous, non-overlapping periods of time. The response specifies the start time and duration of each break.
    # TRAVEL and WAIT are "preemptable": they can be interrupted several times during this transition. Clients can assume that travel happens "as soon as possible" and that "wait" fills the remaining time.
    # A (complex) example:
    #
    #                                TRANSITION[i]
    # --++-----+-----------------------------------------------------------++-->
    #   ||     |       |           |       |           |         |         ||
    #   ||  T  |   B   |     T     |       |     B     |         |    D    ||
    #   ||  r  |   r   |     r     |   W   |     r     |    W    |    e    ||
    #   ||  a  |   e   |     a     |   a   |     e     |    a    |    l    ||
    #   ||  v  |   a   |     v     |   i   |     a     |    i    |    a    ||
    #   ||  e  |   k   |     e     |   t   |     k     |    t    |    y    ||
    #   ||  l  |       |     l     |       |           |         |         ||
    #   ||     |       |           |       |           |         |         ||
    # --++-----------------------------------------------------------------++-->
    struct ShipmentRoute
      include Resource

      # Vehicle performing the route, identified by its index in the source ShipmentModel
      field vehicle_index : Int32

      # Label of the vehicle performing this route, equal to ShipmentModel.vehicles(vehicleIndex).label
      field vehicle_label : String?

      # Time at which the vehicle starts its route
      field vehicle_start_time : Time

      # Time at which the vehicle finishes its route
      field vehicle_end_time : Time

      # Ordered sequence of visits representing a route. visits[i] is the i-th visit in the route.
      # If this field is empty, the vehicle is considered as unused.
      field visits : Array(Visit)

      # Ordered list of transitions for the route
      field transitions : Array(Transition)

      # Indicates that inconsistencies in route timings are predicted using traffic-based
      # travel duration estimates when consider_road_traffic is true
      field has_traffic_infeasibilities : Bool

      # The encoded polyline representation of the route. This field is only populated if
      # OptimizeToursRequest.populate_polylines is set to true
      field route_polyline : EncodedPolyline?

      # Breaks scheduled for the vehicle performing this route
      field breaks : Array(Break)

      # Duration, distance and load metrics for this route
      field metrics : AggregatedMetrics

      # Cost of the route, broken down by cost-related request fields
      field route_costs : Hash(String, Float64)

      # Total cost of the route. The sum of all costs in the cost map
      field route_total_cost : Float64
    end

    # A visit performed during a route. This visit corresponds to a pickup or delivery of a Shipment
    struct Visit
      include Resource

      # Index of the shipments field in the source ShipmentModel
      field shipment_index : Int32

      # If true the visit corresponds to a pickup of a Shipment. Otherwise, it corresponds to a delivery
      field is_pickup : Bool

      # Index of VisitRequest in either the pickup or delivery field of the Shipment
      field visit_request_index : Int32

      # Time at which the visit starts
      field start_time : Time

      # Total visit load demand
      field load_demands : Hash(String, Load)

      # Extra detour time due to the shipments visited on the route before the visit
      field detour : String

      # Copy of the corresponding Shipment.label
      field shipment_label : String?

      # Copy of the corresponding VisitRequest.label
      field visit_label : String?
    end

    # Transition between two events on the route
    struct Transition
      include Resource

      # Travel duration during this transition
      field travel_duration : String

      # Distance traveled during the transition
      field travel_distance_meters : Float64

      # Indicates if traffic info couldn't be retrieved when requested
      field traffic_info_unavailable : Bool

      # Sum of the delay durations applied to this transition
      field delay_duration : String

      # Sum of the duration of the breaks occurring during this transition
      field break_duration : String

      # Time spent waiting during this transition
      field wait_duration : String

      # Total duration of the transition
      field total_duration : String

      # Start time of this transition
      field start_time : Time

      # The encoded polyline representation of the route for this transition
      field route_polyline : EncodedPolyline?

      # Navigation SDK route token
      field route_token : String?

      # Vehicle loads during this transition
      field vehicle_loads : Hash(String, VehicleLoad)
    end

    # The encoded representation of a polyline
    struct EncodedPolyline
      include Resource

      # String representing encoded points of the polyline
      field points : String
    end

    # Data representing the execution of a break
    struct Break
      include Resource

      # Start time of a break
      field start_time : Time

      # Duration of a break
      field duration : String
    end

    # Details of unperformed shipments in a solution
    #
    # See [the documentation](https://developers.google.com/maps/documentation/route-optimization/reference/rest/v1/SkippedShipment) for additional information.
    struct SkippedShipment
      include Resource

      # The index corresponds to the index of the shipment in the source ShipmentModel
      field index : Int32

      # Copy of the corresponding Shipment.label, if specified in the Shipment
      field label : String?

      # A list of reasons that explain why the shipment was skipped.
      # If we are unable to understand why a shipment was skipped, reasons will not be set.
      field reasons : Array(Reason)

      # If we can explain why the shipment was skipped, reasons will be listed here. If the reason is not the same for all vehicles, reason will have more than 1 element. A skipped shipment cannot have duplicate reasons, i.e. where all fields are the same except for exampleVehicleIndex. Example:
      #
      # ```
      # SkippedShipment(
      #   @reasons=[
      #     Reason(
      #       @code=DEMAND_EXCEEDS_VEHICLE_CAPACITY
      #       @example_vehicle_index=1
      #       @example_exceeded_capacity_type="Apples"
      #     ),
      #   ]
      # )
      # ```
      #
      # The skipped shipment is incompatible with all vehicles. The reasons may be different for all vehicles but at least one vehicle's "Apples" capacity would be exceeded (including vehicle 1), at least one vehicle's "Pears" capacity would be exceeded (including vehicle 3) and at least one vehicle's distance limit would be exceeded (including vehicle 1).
      struct Reason
        include Resource

        # Code identifying the reason type
        field code : Code

        # If the reason code is DEMAND_EXCEEDS_VEHICLE_CAPACITY,
        # documents one capacity type that is exceeded
        field example_exceeded_capacity_type : String?

        # If the reason is related to a shipment-vehicle incompatibility,
        # this field provides the index of one relevant vehicle
        field example_vehicle_index : Int32?

        # Code identifying the reason type for skipped shipments
        enum Code
          # This should never be used
          CODE_UNSPECIFIED

          # There is no vehicle in the model making all shipments infeasible
          NO_VEHICLE

          # The demand of the shipment exceeds a vehicle's capacity for some capacity types
          DEMAND_EXCEEDS_VEHICLE_CAPACITY

          # The minimum distance necessary to perform this shipment exceeds the vehicle's routeDistanceLimit
          CANNOT_BE_PERFORMED_WITHIN_VEHICLE_DISTANCE_LIMIT

          # The minimum time necessary to perform this shipment, including travel time,
          # wait time and service time exceeds the vehicle's routeDurationLimit
          CANNOT_BE_PERFORMED_WITHIN_VEHICLE_DURATION_LIMIT

          # Same as above but we only compare minimum travel time and the vehicle's
          # travelDurationLimit
          CANNOT_BE_PERFORMED_WITHIN_VEHICLE_TRAVEL_DURATION_LIMIT

          # The vehicle cannot perform this shipment in the best-case scenario if it
          # starts at its earliest start time
          CANNOT_BE_PERFORMED_WITHIN_VEHICLE_TIME_WINDOWS

          # The allowedVehicleIndices field of the shipment is not empty and this
          # vehicle does not belong to it
          VEHICLE_NOT_ALLOWED
        end
      end
    end

    struct InjectedSolutionConstraint
      include Resource
    end

    struct Metrics
      include Resource

      # Aggregated over the routes. Each metric is the sum (or max, for loads) over all ShipmentRoute.metrics fields of the same name.
      field aggregated_route_metrics : AggregatedMetrics

      # Number of mandatory shipments skipped.
      field skipped_mandatory_shipment_count : Int64

      # Number of vehicles used. Note: if a vehicle route is empty and Vehicle.used_if_route_is_empty is true, the vehicle is considered used.
      field used_vehicle_count : Int64

      # The earliest start time for a used vehicle, computed as the minimum over all used vehicles of ShipmentRoute.vehicle_start_time.
      field earliest_vehicle_start_time : Time

      # The latest end time for a used vehicle, computed as the maximum over all used vehicles of ShipmentRoute.vehicle_end_time.
      field latest_vehicle_end_time : Time

      # Cost of the solution, broken down by cost-related request fields. The keys are proto paths, relative to the input OptimizeToursRequest, e.g. "model.shipments.pickups.cost", and the values are the total cost generated by the corresponding cost field, aggregated over the whole solution. In other words, costs["model.shipments.pickups.cost"] is the sum of all pickup costs over the solution. All costs defined in the model are reported in detail here with the exception of costs related to TransitionAttributes that are only reported in an aggregated way as of 2022/01.
      field costs : Hash(String, Float64)

      field total_cost : Float64
    end

    enum SolvingMode
      # Solve the model. Warnings may be issued in `OptimizeToursResponse#validation_errors`.
      DEFAULT_SOLVE

      # Only validates the model without solving it: poplates as many `OptimizeToursResponse#validation_errors` as possible.
      VALIDATE_ONLY

      # Only populates `OptimizeToursResponse#validation_errors` or
      # `OptimizeToursResponse#skipped_shipments`, and doesn't actually solve the
      # rest of the request (`status` and `routes` are unset in the response). If
      # infeasibilities in `injectedSolutionConstraint` routes are detected they
      # are populated in the `OptimizeToursResponse#validation_errors` field and
      # `OptimizeToursResponse#skipped_shipments` is left empty.
      #
      # IMPORTANT: not all infeasible shipments are returned here, but only the
      # ones that are detected as infeasible during preprocessing.
      DETECT_SOME_INFEASIBLE_SHIPMENTS
    end

    enum SearchMode
      # Unspecified search mode, equivalent to RETURN_FAST
      SEARCH_MODE_UNSPECIFIED

      # Stop the search after finding the first good solution
      RETURN_FAST

      # Spend all the available time to search for better solutions
      CONSUME_ALL_AVAILABLE_TIME
    end
  end
end
