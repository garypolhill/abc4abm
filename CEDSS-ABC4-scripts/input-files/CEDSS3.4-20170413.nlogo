;;     CEDSS version 3.4, an agent-based model of household energy demand
;;     Copyright (C) 2016  Nick Gotts, Gary Polhill and The James Hutton Research Institute
;;
;;     This program is free software: you can redistribute it and/or modify
;;     it under the terms of the GNU General Public License as published by
;;     the Free Software Foundation, either version 3 of the License, or
;;     (at your option) any later version.
;;
;;     This program is distributed in the hope that it will be useful,
;;     but WITHOUT ANY WARRANTY; without even the implied warranty of
;;     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;     GNU General Public License for more details.
;;
;;     You should have received a copy of the GNU General Public License
;;     along with this program.  If not, see <http://www.gnu.org/licenses/>.


;; Enable the profiler, arrays and "tables" (property-value lists) to be used.
extensions [array table profiler]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                                            ;;
;; Globals                                                                    ;;
;;                                                                            ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

globals [
  patch-legend
  energy-price ;; The current table of fuel-type to price.
  energy-price-list ;; A list of tables of fuel-type to price.
  use-social-links ;; Boolean: whether to use a predefined list of social links
                   ;; between households.
  steps-all-household-total-energy-use ;; Total energy use during current step.
  steps-all-household-appliance-energy-use ;; Energy use for non-heating appliances during current step.
  steps-all-household-heating-energy-use ;; Energy use for space and water heating during current step.
  all-household-capital-reserves
  external-influences-list ;; Each entry specifies an external influence on household value-strengths,
                           ;; operating during a particular step.
  triggers-list ;; Each entry specifies a "trigger" that can over-ride the selected goal-frame.
                ;; Interpreted using the procedure adjust-goal-frame.

  patch-links ;; A table of household type and dwelling type to probability of link.
  link-radii-list
  radius-links ;; A table of household type and dwelling type to probability of link when
               ;; dwellings are within specified radii.
  link-patch-types-list
  patch-type-links ;; A table of household type and dwelling type to probability of patch link.
  patch-blocks ;; A list of block-ids; blocks are sets of contiguous patches of the same type.
  next-block-id

  ;; Next 2 lines: currently appliance usage-modes are not used, but could be.
  usage-mode-matrix ;; A table of goal-frame to table of usage-mode conditions.
  usage-modes-list

  household-types-list ;; Currently households are all of one type.
  dwelling-types-list
  steps-list ;; A list of natural numbers from 1 to number of steps per year.
  dwelling-temp-colours
  new-subcategories ;; List of subcategories of appliances that have newly become
                    ;; available in the last new-subcategory-steps steps.
  land-fill ;; list of items discarded during current step.
  tenure-types-list
  all-insulation-states
  insulation-updates ;; A list of which each item specifies a change in the availability
                     ;; or cost of an upgrade to insulation.
  maximum-in-category-table ;; Table specifying a maximum number of appliances a household
                            ;; may own in each category.
  initial-hh-appliances ;; Table of initial appliances for specific households.
  initial-hh-dw-type-appliances ;; Table of initial appliances for households of given
                                ;; type at dwelling of given type and tenure.
  initial-hh-address-appliances ;; Table of initial appliances for households of given
                                ;; type at a specific address.
  current-appliances ;; List of all the models of appliances currently on the market.

  ;; Remaining lines are for dummy variables used in debugging.
  test-list
  test-item
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                                            ;;
;; Breeds                                                                     ;;
;;                                                                            ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

patches-own [
  patch-type
  block-id ;; Patches are grouped into "blocks" of the same kind of patch
           ;; (dwelling, street, park...).
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; dwellings
;;
;; Dwellings are locations where households live. Each dwelling belongs to one
;; household, and is located on one patch in the space. Each patch may, however
;; contain more than one dwelling.

breed [dwellings dwelling]

dwellings-own [
  dwelling-id
  dwelling-type
  tenure ;; Currently 'owned' or 'rented' (or something ending in 'rented').
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; households
;;
;; Households are the main 'agents' (in the agent-based social simulation sense)
;; of the model. (In the NetLogo sense of "agent", there are also a number of
;; other breeds of agent (see below). Households buy appliances and insulation,
;; receive income, and use energy.

breed [households household]

households-own [
  household-id
  household-type
  steply-net-income ;; A list of amounts received in each step of a run.
  capital-reserve
  hedonic ;; This and the next two properties are value-strengths.
  egoistic
  biospheric
  goal-frame
  usage-mode ;; Currently only one is available.
  planning-horizon ;; Used for financial and energy-saving calculations.
  frame-adjustment ;; Helps determine how households influence each others' value-strengths.
  breakdown-list ;; Currently broken appliances.
  wish-list ;; Currently wished-for appliances.
  steps-total-energy-use ;; Total energy use by household during current step.
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; appliances
;;
;; Appliances are energy consuming devices used by households.

breed [appliances appliance]

appliances-own [
  category
  subcategory
  name
  essential?
  hedonic-score ;; Not used at present (all appliances have the same score).
  cost-list
  embodied-energy ;; Not used at present.
  energy-rating ;; Lower numbers imply lower energy usage.
  energy-rating-provided? ;; Boolean; if false, energy-rating will be NA, but in practice,
                          ;; all items in a category can be given the same rating, with
                          ;; the same effect.
  breakdown-probability ;; Per step.
  first-step-available
  last-step-available
  last-step-available-unbounded? ;; Boolean: false if appliance becomes unavailable
                                 ;; before end of run.
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; consumption-patterns
;;
;; Patterns of fuel consumption for appliances.

breed [consumption-patterns consumption-pattern]

consumption-patterns-own [
  for-household-type
  for-dwelling-type
  for-tenure-type
  for-purpose ;; Heating-systems are used both for space-heating and water-heating.
              ;; Cookers have both an oven and a hob.
  in-usage-mode ;; Only one usage-mode, "normal" is currently defined. Defining additional modes
                ;; (e.g. for household economy drives) would require added code - see
                ;; procedure "get-usage-mode".
  in-step
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; fuel
;;
;; Fuel is used by appliances.

breed [fuels fuel]

fuels-own [
  fuel-type
  unit
  kWh-per-unit
  total-kWh ;; For observation.
  fuel-plot-colour ;; For observation.
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; insulation
;;
;; Insulation saves fuel.

breed [insulations insulation]

insulations-own [
  insulation-state ;; Type of insulation.
  insulation-dwelling-type ;; Dwelling type to which the fuel use factor applies.
  fuel-use-factor ;; It is assumed the same factor applies to all fuel types.
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; links
;;
;; Links between various kinds of object/agent.

;; Households own appliances.
directed-link-breed [ownerships ownership]
ownerships-own [
  broken?
  age ;; How long an appliance has been owned.
]

;; Using appliances for a particular purpose has a consumption-pattern that
;; consumes fuel.
directed-link-breed [consumes consume]
directed-link-breed [uses use]
uses-own [
  units-per-use
]

;; Insulations (insulation states would be a more accurate term) insulate dwellings.
directed-link-breed [insulates insulate]

;; Insulations have upgrade costs for each dwelling-type.
directed-link-breed [upgrades upgrade]
upgrades-own [
  upgrade-cost ;; Table of dwelling-type to cost.
]

;; Households live in dwellings.
directed-link-breed [addresses address]

;; Appliances can replace each other.
directed-link-breed [replacements replacement]

;; Households have social links with each other.
undirected-link-breed [social-links social-link]
social-links-own [
  n-visits
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                                            ;;
;; Button procedures                                                          ;;
;;                                                                            ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; profile
;;
;; Use the profiler to get timings for running the model.

to profile
  profiler:start
  setup
  repeat halt-after [
    go
  ]
  profiler:stop
  print profiler:report
  print profile-setup
  print profile-go
  profiler:reset
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; setup
;;
;; Set the model up for a run.

to setup
  file-close-all ;; Added 20120319 by GP because if NetLogo stops with an error
                 ;; whilst reading a file, it doesn't close it.
  show-licence-message
  clear-all
  setup-files
  output-print "setup-files"
  ifelse social-link-matrix-file = false or social-link-matrix-file = "null" or length social-link-matrix-file = 0 [
    set use-social-links false
  ]
  [
    set use-social-links true
  ]
  setup-globals
  output-print "setup-globals"
  setup-insulation
  output-print "setup-insulation"
  setup-patches
  output-print "setup-patches"
  setup-energy
  output-print "setup-energy"
  setup-appliances
  output-print "setup-appliances"
  setup-households
  output-print "setup-households"
  show-changes

  let colour-array array:from-list [red orange brown yellow green lime turquoise
    cyan sky blue violet magenta pink]
  let i 0
  set-current-plot "Appliances"
  foreach sort remove-duplicates [category] of appliances [
    create-temporary-plot-pen ?
    set-plot-pen-color array:item colour-array
      ((i mod (array:length colour-array)) + int(i / (array:length colour-array)))
    set i i + 1
  ]

  let colour-array-2 array:from-list [5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80
    85 90 95 100]
  let j 0
  set-current-plot "Appliance subcategories"
  foreach sort remove-duplicates [subcategory] of appliances [
    create-temporary-plot-pen ?
    set-plot-pen-color array:item colour-array-2
      ((j mod (array:length colour-array-2)) + int(j / (array:length colour-array-2)))
    set j j + 1
  ]

  let colour-array-3 array:from-list [5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80
    85 90 95 100]
  let k 0
  set-current-plot "Insulation states"
  foreach sort remove-duplicates [insulation-state] of insulations [
    create-temporary-plot-pen ?
    set-plot-pen-color array:item colour-array-3
      ((k mod (array:length colour-array-3)) + int(j / (array:length colour-array-3)))
    set k k + 1
  ]

  output-print "removed-duplicates"
  if count fuels > 1 [
    set-current-plot "Total energy use"
    ask fuels [
      create-temporary-plot-pen fuel-type
      set-current-plot-pen fuel-type
      set-plot-pen-color fuel-plot-colour
    ]
  ]
  reset-ticks
  output-print "reset-ticks"
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; go
;;
;; Perform one time-step of the model.

to go
  set current-appliances appliances with [first-step-available <= ticks and (last-step-available-unbounded? or last-step-available >= ticks)]

  update-insulation-upgrades

  ask fuels [
    set total-kWh 0
  ]
  ask ownerships [
    set age age + 1
  ]

  calculate-breakdowns
  update-globals

  ask households [
    step
  ]

  tick
  show-changes
  my-update-plots

  set steps-all-household-appliance-energy-use calculate-appliance-energy-use
  set steps-all-household-heating-energy-use calculate-heating-energy-use
  output-print steps-all-household-appliance-energy-use
  output-print steps-all-household-heating-energy-use

  if (ticks = halt-after) [
    stop
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; calculate-appliance-energy-use
;;
;; Calculate appliance energy use for a step, to be output at the end of each step.
;;

to-report calculate-appliance-energy-use
  let appliance-energy-use 0
  ask fuels with [fuel-type = "appliance-gas" or fuel-type = "appliance-elect"] [
    set appliance-energy-use appliance-energy-use + total-kWh
  ]
  report appliance-energy-use
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; calculate-heating-energy-use
;;
;; Calculate heating energy use for a step, to be output at the end of each step.
;;

to-report calculate-heating-energy-use
  let heating-energy-use 0
  ask fuels with [fuel-type != "appliance-gas" and fuel-type != "appliance-elect"] [
    set heating-energy-use heating-energy-use + total-kWh
  ]
  report heating-energy-use
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; my-update-plots
;;
;; Update all the plots.

to my-update-plots
  set-current-plot "Total energy use"
  set-current-plot-pen "default"
  plot steps-all-household-total-energy-use
  if count fuels > 1 [
    ask fuels [
      set-current-plot-pen fuel-type
      plot total-kWh
    ]
  ]

  set-current-plot "Total capital reserves"
  plot all-household-capital-reserves

;; This and similar conditionals condition are included to make the use of social links optional.
;; Note that currently all social links are undirected, and this code counts the link in both
;; directions.
  if use-social-links [
    set-current-plot "Number of links"
    let link-count sum [count social-link-neighbors] of households
    plot link-count
  ]

  set-current-plot "Appliances"
  set-current-plot-pen "default"
  plot count ownerships
  foreach sort remove-duplicates [category] of appliances [
    set-current-plot-pen ?
    let osum 0
    ask households [
      set osum osum + count (out-ownership-neighbors with [category = ?])
    ]
    plot osum
  ]

  set-current-plot "Appliance subcategories"
  foreach sort remove-duplicates [subcategory] of appliances [
    set-current-plot-pen ?
    let osum 0
    ask households [
      set osum osum + count (out-ownership-neighbors with [subcategory = ?])
    ]
    plot osum
  ]

  set-current-plot "Land fill"
  let i 0
  plot-pen-reset
  foreach sort remove-duplicates [subcategory] of appliances [
    set i i + 1
    let subcat ?
    plot length (filter [[subcategory] of ? = subcat] land-fill)
    if ticks = 1 [
      print (word "Land fill plot " i " is subcategory " subcat)
    ]
  ]

  set-current-plot "Insulation states"
  foreach all-insulation-states [
    set-current-plot-pen ?
    let osum 0
    ask dwellings [
      set osum osum + count (in-insulate-neighbors with [insulation-state = ?])
    ]
    plot osum
  ]

  set-current-plot "Goal frame"
  set-current-plot-pen "enjoy"
  plot count households with [goal-frame = "enjoy"]
  set-current-plot-pen "gain"
  plot count households with [goal-frame = "gain"]
  set-current-plot-pen "sustain"
  plot count households with [goal-frame = "sustain"]

  set-current-plot "Goal frame parameters"
  set-current-plot-pen "hedonic"
  plot mean [hedonic] of households
  set-current-plot-pen "egoistic"
  plot mean [egoistic] of households
  set-current-plot-pen "biospheric"
  plot mean [biospheric] of households

  set-current-plot "Visits per link"
  set-current-plot-pen "mean"
  if use-social-links and count social-links > 0 [
    plot mean [n-visits] of social-links
    set-current-plot-pen "min"
    plot min [n-visits] of social-links
    set-current-plot-pen "max"
    plot max [n-visits] of social-links
  ]
  if use-social-links and count social-links = 0 [
    plot 0
    set-current-plot-pen "min"
    plot 0
    set-current-plot-pen "max"
    plot 0
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                                            ;;
;; Procedures for setting up/creating the model.                              ;;
;;                                                                            ;;
;; Note that these procedures do not include those for reading/writing to a   ;;
;; file. There is a separate section in the code for those.                   ;;
;;                                                                            ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; setup-files
;;
;; Set up the file names to use, if the interface switch "user-files" is set to true.

to setup-files
  if user-files [
    user-message "Choose patch legend file (1)"
    set patch-legend-file user-file
    user-message "Choose patch file (2)"
    set patch-file user-file
    user-message "Choose dwellings file (3)"
    set dwellings-file user-file

    user-message "Choose energy prices file (12)"
    set energy-prices-file user-file
    user-message "Choose fuel file (10)"
    set fuel-file user-file
    user-message "Choose usage-mode matrix file (7)"
    set usage-mode-matrix-file user-file

    user-message "Choose appliances file (8)"
    set appliances-file user-file
    user-message "Choose appliances replacement file (9)"
    set appliances-replacement-file user-file
    user-message "Choose appliances fuel file (11)"
    set appliances-fuel-file user-file
    user-message "Choose maximum in category file (16)"
    set maximum-in-category-file user-file
    user-message "Choose household initial appliances file (17)"
    set household-init-appliance-file user-file

    ifelse use-household-file [
      user-message "Choose household file (4)"
      set household-file user-file
    ]
    [
      set household-file false
    ]
    user-message "Choose social link matrix file (5) (click cancel if you do not want social links)"
    set social-link-matrix-file user-file
    ifelse use-social-link-file [
      user-message "Choose social link file (6)"
      set social-link-file user-file
    ]
    [
      set social-link-file false
    ]

    user-message "Choose insulation file (13)"
    set insulation-file user-file
    user-message "Choose insulation upgrade file (14)"
    set insulation-upgrade-file user-file
    user-message "Choose insulation update file (15)"
    set insulation-update-file user-file

    user-message "Choose triggers file (18)"
    set triggers-file user-file

    user-message "Choose external influences file (19)"
    set external-influences-file user-file

    set user-files false
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; setup-globals
;;
;; Set up some global variables. Read in the maximum in category, external influence
;; and trigger files (these are files it is convenient to read in early during setup).

to setup-globals
  set next-block-id 0

  set steps-list n-values steps-per-year [? + 1]
  ;; nvalues steps-per-year [? + 1] produces the list [1 2 3... <steps-per-year>]

  set dwelling-temp-colours array:from-list [102 blue cyan turquoise green
    yellow orange red pink 138]

  set land-fill []
  set maximum-in-category-table read-table2 maximum-in-category-file
  set initial-hh-appliances false
  read-external-influences external-influences-file
  read-triggers triggers-file
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; setup-insulation
;;
;; Set up the current insulation of dwellings, the currently possible upgrades,
;; and future changes in the availability and cost of upgrades.

to setup-insulation
  read-insulation-file insulation-file
  read-insulation-upgrade-file insulation-upgrade-file
  read-insulation-update-file insulation-update-file
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; setup-patches
;;
;; Read in the patch layout and dwelling files, group patches into blocks of the
;; same type of terrain (this information is used in setting up social links
;; between households).

to setup-patches
  set patch-legend read-table patch-legend-file
  foreach table:keys patch-legend [
    if(is-string? (table:get patch-legend ?)) [
      table:put patch-legend ? (read-from-string (table:get patch-legend ?));
    ]
  ]
  read-patch-layout patch-file
  read-dwellings-file dwellings-file

  set dwelling-types-list remove-duplicates [dwelling-type] of dwellings
  set tenure-types-list remove-duplicates [tenure] of dwellings

  determine-patch-type-blocks
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; setup-appliances
;;
;; Read in data on what appliances are available, which appliances
;; are sufficiently similar to replace each other, appliances' fuel
;; use, and what appliances households initially own.

to setup-appliances
  read-appliances appliances-file
  output-print "read-appliances"
  ask households [
  ]
  read-replacements appliances-replacement-file
  output-print "read-replacements"
  read-appliances-fuel-use appliances-fuel-file
  output-print "read-appliances-fuel-use"
  if(household-init-appliance-file != false and household-init-appliance-file != "null") [
    read-initial-appliances-file household-init-appliance-file
  output-print "read-initial-appliances-file"
  ]

  ask appliances with [not last-step-available-unbounded?] [
    if count my-out-replacements = 0 [
      output-print (word "*** Warning: There are no replacements for appliance \"" name "\"")
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; setup-energy
;;
;; Set up energy/fuel types, and price series for the run. Set up usage-modes (of
;; which only one is currently defined).

to setup-energy
  read-fuel fuel-file
  read-energy-prices energy-prices-file
  set usage-mode-matrix read-matrix usage-mode-matrix-file

  set usage-modes-list []
  foreach table:keys usage-mode-matrix [
    let umodes table:get usage-mode-matrix ?
    foreach table:keys umodes [
      set usage-modes-list fput ? usage-modes-list
    ]
  ]
  set usage-modes-list remove-duplicates usage-modes-list
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; setup-households
;;
;; Create and intialise the households, the appliances they own and their social
;; links, and related global variables.

to setup-households
  ifelse use-household-file [
    read-households-file household-file
    set household-types-list remove-duplicates [household-type] of households
    ask households [
      allocate-initial-appliances
    ]
  ]

  [
    set household-types-list []
  ]

  if use-social-links [
    read-social-link-matrix-file social-link-matrix-file
  ]

  ask households [
    if use-social-links [
      make-random-social-links
    ]

    set breakdown-list []

    set wish-list []

    set goal-frame choose-goal-frame
  ]
  if use-social-link-file [
    read-social-link-file social-link-file
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; allocate-initial-appliances
;;
;; Allocate the initial appliances of a household.

to allocate-initial-appliances

  ;; Default initial appliances are defined by first/last step available in the
  ;; appliance file: first-step-available will be negative if and only if it
  ;; is assumed that all households will initially have the appliance.
  create-ownerships-to appliances with [first-step-available < 0 and last-step-available <= ticks] [
    set hidden? true
    set broken? false
    set age 0
  ]

  ;; Has an initial appliance list been specifically defined for this household?
  if initial-hh-appliances != false [
    ifelse table:has-key? initial-hh-appliances household-id [
      foreach (table:get initial-hh-appliances household-id) [
        create-ownerships-to appliances with [name = ?] [
          set hidden? true
          set broken? false
          set age 0
        ]
      ]
      table:remove initial-hh-appliances household-id
    ]
    [
      let my-dw one-of out-address-neighbors

      let hh-address (word household-type ":" ([dwelling-id] of my-dw))

      ;; Has an initial appliance list been defined for this household type at this
      ;; specific address?
      ifelse table:has-key? initial-hh-address-appliances hh-address [
        foreach (table:get initial-hh-address-appliances hh-address) [
          create-ownerships-to appliances with [name = ?] [
            set hidden? true
            set broken? false
            set age 0
          ]
        ]
      ]
      [
        let hh-dw-type (word household-type ":" ([tenure] of my-dw) ":" ([dwelling-type] of my-dw))

        ;; Has an initial appliance list been defined for this household type with this
        ;; dwelling-type and tenure combination?
        if table:has-key? initial-hh-dw-type-appliances hh-dw-type [
          foreach (table:get initial-hh-dw-type-appliances hh-dw-type) [
            create-ownerships-to appliances with [name = ?] [
              set hidden? true
              set broken? false
              set age 0
            ]
          ]
        ]
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; set-household-nlogo-params
;;
;; Set the NetLogo parameters of how a household is displayed on the interface:
;; its shape, size and location.

to set-household-nlogo-params
  set shape "face happy"
  set size 0.5
  set xcor [xcor] of [other-end] of one-of my-out-addresses
  set ycor [ycor] of [other-end] of one-of my-out-addresses
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; determine-patch-type-blocks
;;
;; Determine sets of patches in blocks of common patch-types. This uses two
;; approaches, an efficient one that works if the world is not wrapped, and
;; a less efficient one that can be used otherwise.

to determine-patch-type-blocks
  ask patches [
    set block-id 0
  ]

  ifelse (count [neighbors4] of patch min-pxcor min-pycor) > 2 [
    ;; the world wraps in one or more dimensions
    ask patches [
      set-block-id ;; This approach is a bit inefficient
    ]
  ]
  [
    ;; The world does not wrap -- use more efficient procedure.
    let px min-pxcor

    while [px <= max-pxcor] [
      let py min-pycor

      while [py <= max-pycor] [
        ask patch px py [
          let my-patch-type patch-type
          let nbrs neighbors4 with [patch-type = my-patch-type and (not (block-id = 0))]
          ifelse count nbrs > 0 [
            ;; We can get the patch ID from the Von-Neumann neighbours.
            let idlist [block-id] of nbrs
            set block-id first idlist

            set idlist but-first idlist
            foreach idlist [
              ;; Deal with neighours with different block-ids.
              if ? != block-id [
                ask patches with [block-id = ?] [
                  set block-id [block-id] of myself
                ]
              ]
            ]
          ]
          [
            ;; All the neighbours have block-id 0 or different patch-type.
            set next-block-id next-block-id + 1
            set block-id next-block-id
          ]
        ]
        set py py + 1
      ]
      set px px + 1
    ]
  ]

  ;; Get the list of unique block-ids of patches.
  set patch-blocks (remove-duplicates ([block-id] of patches))
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; set-block-id
;;
;; Set the block-id of a patch (recursively checking all neighbouring patches).

to set-block-id
  let my-patch-type patch-type
  ifelse block-id = 0 [
    let same-nbrs neighbors4 with [patch-type = my-patch-type]
    ifelse count same-nbrs > 0 [
      let same-nbrs-block same-nbrs with [block-id != 0]
      ifelse count same-nbrs-block > 0 [
        ;; Some neighbours with the same patch-type have a block-id we can use.
        let block-ids [block-id] of same-nbrs-block
        set block-id first block-ids

        set block-ids but-first block-id
        let my-block-id block-id
        foreach block-ids [
          ;; Recursively ensure all neighbours with the same patch-type have
          ;; the same block-id.
          if ? != block-id [
            ask patches with [block-id = ?] [
              set-block-id-to my-block-id
            ]
          ]
        ]

        ;; Recursively ensure all neighbours with the same patch-type that
        ;; have not had their block-id set yet have this block-id.
        ask same-nbrs with [block-id = 0] [
          set-block-id-to my-block-id
        ]
      ]
      [
        ;; There are no neighbours from which to get a block-id: Set this
        ;; block-id to the next one, and recursively set the block-id of
        ;; neighbours with the same patch-type.
        set next-block-id next-block-id + 1
        set block-id next-block-id
        ask same-nbrs [
          set-block-id-to next-block-id
        ]
      ]
    ]
    [
      ;; No neighbours with the same patch-type -- just set this patch's
      ;; unique block id.
      set next-block-id next-block-id + 1
      set block-id next-block-id
    ]
  ]
  [
    ;; The block-id has already been set -- recursively ensure neighbours with
    ;; the same patch-type have the same block-id.
    let my-block-id block-id
    ask neighbors4 with [patch-type = my-patch-type and block-id != my-block-id] [
      set-block-id-to my-block-id
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Recursively set the block-id of neighbouring patches with the same patch-type.

to set-block-id-to [a-block-id]
  set block-id a-block-id
  let my-patch-type patch-type
  ask neighbors4 with [patch-type = my-patch-type and block-id != a-block-id] [
    set-block-id-to a-block-id
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; make-random-social-links
;;
;; Use the rules defined in the social-link-matrix-file to create random social
;; links among households.

to make-random-social-links
  let dw-type [dwelling-type] of one-of out-address-neighbors
  ;; The above assumes one address per household.

  let my-type (word household-type ":" dw-type)
  let my-anydtype (word household-type ":*")
  let my-anyhtype (word "*:" dw-type)
  ifelse table:has-key? patch-links my-type [
    make-random-social-links-type my-type
  ]
  [
    ifelse table:has-key? patch-links my-anydtype [
      make-random-social-links-type my-anydtype
    ]
    [
      ifelse table:has-key? patch-links my-anyhtype [
        make-random-social-links-type my-anyhtype
      ]
      [
        if table:has-key? patch-links "*:*" [
          make-random-social-links-type "*:*"
        ]
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; make-random-social-links-type
;;
;; Make random social links for the specified household type and dwelling type.

to make-random-social-links-type [key]
  make-patch-social-links (table:get patch-links key)

  if length link-radii-list > 0 [
    make-radius-social-links (table:get radius-links key)
  ]

  if length link-patch-types-list > 0 [
    make-patch-type-social-links (table:get patch-type-links key)
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; make-patch-social-links
;;
;; Make social links with households on the same patch.

to make-patch-social-links [link-table]
  let hh self

  ask households-here  with [self != hh] [
    let dw-type [dwelling-type] of one-of out-address-neighbors
    let this-type (word household-type ":" dw-type)
    let this-anydtype (word household-type ":*")
    let this-anyhtype (word "*:" dw-type)

    ifelse table:has-key? link-table this-type [
      make-patch-social-links-type link-table this-type hh
    ]
    [
      ifelse table:has-key? link-table this-anydtype [
        make-patch-social-links-type link-table this-anydtype hh
      ]
      [
        ifelse table:has-key? link-table this-anyhtype [
          make-patch-social-links-type link-table this-anyhtype hh
        ]
        [
          if table:has-key? link-table "*:*" [
            make-patch-social-links-type link-table "*:*" hh
          ]
        ]
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; make-patch-social-links-type
;;
;; Construct a social link with a household of a specified type on the same patch.

to make-patch-social-links-type [link-table key hh]
  let link-p read-from-string table:get link-table key
  if (count social-link-neighbors < max-links) [
    if random-float 1 < link-p and not social-link-neighbor? hh [
      create-social-link-with hh
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; make-radius-social-links
;;
;; Make social links with households within specified distances.

to make-radius-social-links [link-table]
  let hh self
  let hh-patch [patch-here] of hh
  ask households [
    let dw-type [dwelling-type] of one-of out-address-neighbors
    let this-type (word household-type ":" dw-type)
    let this-anydtype (word household-type ":*")
    let this-anyhtype (word "*:" dw-type)

    ifelse table:has-key? link-table this-type [
      make-radius-social-links-type link-table this-type hh hh-patch
    ]
    [
      ifelse table:has-key? link-table this-anydtype [
        make-radius-social-links-type link-table this-anydtype hh hh-patch
      ]
      [
        ifelse table:has-key? link-table this-anyhtype [
          make-radius-social-links-type link-table this-anyhtype hh hh-patch
        ]
        [
          if table:has-key? link-table "*:*" [
            make-radius-social-links-type link-table "*:*" hh hh-patch
          ]
        ]
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; make-radius-social-links-type
;;
;; Make social links with households of a given type within specified ditances.

to make-radius-social-links-type [link-table key hh hh-patch]
  (foreach link-radii-list (table:get link-table key) [
    if (count social-link-neighbors < max-links) [
      if [distance hh-patch] of patch-here <= ?1 [
        if random-float 1 < read-from-string ?2 and not social-link-neighbor? hh [
          create-social-link-with hh
        ]
      ]
    ]
  ])
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; make-patch-type-social-links
;;
;; Make social links with households in or bordering shared patch blocks.

to make-patch-type-social-links [link-table]
  let hh self
  let hh-patch [patch-here] of hh
  let hh-nbr-block-ids [block-id] of ([neighbors] of hh-patch)

  ask households [
    let dw-type [dwelling-type] of one-of out-address-neighbors
    let this-type (word household-type ":" dw-type)
    let this-anydtype (word household-type ":*")
    let this-anyhtype (word "*:" dw-type)

    ifelse table:has-key? link-table this-type [
      make-patch-type-social-links-type link-table this-type hh hh-patch hh-nbr-block-ids
    ]
    [
      ifelse table:has-key? link-table this-anydtype [
        make-patch-type-social-links-type link-table this-anydtype hh hh-patch hh-nbr-block-ids
      ]
      [
        ifelse table:has-key? link-table this-anyhtype [
          make-patch-type-social-links-type link-table this-anyhtype hh hh-patch hh-nbr-block-ids
        ]
        [
          if table:has-key? link-table "*:*" [
            make-patch-type-social-links-type link-table "*" hh hh-patch hh-nbr-block-ids
          ]
        ]
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; make-patch-type-social-links-type
;;
;; Make social links with households of specified household and dwelling type
;; in or bordering shared patch blocks.

to make-patch-type-social-links-type [link-table key hh hh-patch hh-nbr-block-ids]
  (foreach link-patch-types-list (table:get link-table key) [
    ifelse ?1 = "dwelling" [
      ;; dwelling patch type -- both households' dwellings must be in the
      ;; same block...
      if (count social-link-neighbors < max-links) [
        if [block-id] of hh-patch = [block-id] of patch-here [
          if random-float 1 < read-from-string ?2 and not social-link-neighbor? hh [
            create-social-link-with hh
          ]
        ]
      ]
    ]
    [
      ;; ... for all other patch types, both households' dwellings must be
      ;; neighbours of the same block of the required type
      let my-nbr-block-ids [block-id] of (([neighbors] of patch-here) with [patch-type = ?1])
      if (count social-link-neighbors <= max-links) [
        if length intersection hh-nbr-block-ids my-nbr-block-ids > 0 [
          if random-float 1 < read-from-string ?2 and not social-link-neighbor? hh and hh != self [
            create-social-link-with hh
          ]
        ]
      ]
    ]
  ])
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                                            ;;
;; Procedures for running a time-step of the model                            ;;
;;                                                                            ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; update-globals
;;
;; Update global variables at the start of a step.

to update-globals
  if (ticks < length energy-price-list) [
    set energy-price (item ticks energy-price-list)
  ]
  set steps-all-household-total-energy-use 0
  set all-household-capital-reserves 0

  ;; Get the list of subcategories of appliances introduced in the last
  ;; new-subcategory-steps.

  set new-subcategories []
  let new-appliance-subcategories [subcategory] of current-appliances with
    [first-step-available >= (ticks - new-subcategory-steps)]
  foreach remove-duplicates new-appliance-subcategories [
    if (count (appliances with [(subcategory = ?) and
      (first-step-available < (ticks - new-subcategory-steps))]) = 0) [
      set new-subcategories (fput ? new-subcategories)
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; step
;;
;; Perform one step of the model (for households).

to step

  set goal-frame choose-goal-frame
  adjust-goal-frame
  set usage-mode get-usage-mode

  calculate-moeu ;; Overall energy use for this step.
  calculate-finance

  replace-broken-appliances
  ifelse goal-frame = "enjoy" [
    let host false
    let visited []
    if count social-link-neighbors > 0 [
      repeat visits-per-step [
        set  host one-of social-link-neighbors
        visit host
        set visited lput host visited
      ]
    ]
    update-wish-list visited
    enjoy-equip-nonessential
  ]
  [
    if [tenure] of one-of out-address-neighbors = "owned" [
      buy-insulation
    ]
    ifelse (goal-frame = "gain") [
      gain-equip-nonessential
    ]
    [
      sustain-equip-nonessential
    ]
    if count social-link-neighbors > 0 [
      repeat visits-per-step [
        visit one-of social-link-neighbors
      ]
    ]
  ]
  if use-social-links [
    update-links
  ]
  absorb-external-influences
  set all-household-capital-reserves all-household-capital-reserves + capital-reserve
  set steps-all-household-total-energy-use (steps-all-household-total-energy-use
    + steps-total-energy-use)
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; replace-broken-appliances
;;
;; How households replace their broken appliances using their current goal-frame.

to replace-broken-appliances
  let broken-appliances []

  ask my-out-ownerships with [broken? = true] [
    set broken-appliances fput other-end broken-appliances
    set land-fill fput other-end land-fill
    die
  ]

  let my-dwelling one-of out-address-neighbors

  foreach broken-appliances [
    let broken-appliance ?
    ;; All essential appliances are landlord-supplied, the cheapest being selected.
    ;; Note that a broken appliance will only be replaced in this procedure
    ;; if the household owns no other appliance in the same category.
    ifelse [essential?] of broken-appliance and one-of (my-out-ownerships
        with [[category] of other-end = [category] of broken-appliance]) = nobody [
      let newitem false

      let this-tenure [tenure] of my-dwelling

      ifelse length this-tenure >= 6 and substring (reverse this-tenure) 0 6 = "detner" [
        ;; This rather obscure line specifies that the tenure must end with "rented".
        ;; This is to allow for the possibility of distinguishing different
        ;; types of rented property e.g. private or social.
        set newitem gain-ess-choose-replacement broken-appliance
        ifelse newitem != false and is-agent? newitem and newitem != nobody [
          add-item-cost-free newitem 0
        ]
        [
          output-print (word "*** Warning: renting household \"" household-id
            "\" could not replace essential appliance \"" [name] of broken-appliance "\"")
          set breakdown-list (fput broken-appliance breakdown-list)
        ]
      ]
      [
        ifelse goal-frame = "enjoy" [
          set newitem enjoy-ess-choose-replacement broken-appliance
        ]
        [
          ifelse goal-frame = "gain" [
            ifelse  [category] of broken-appliance = "heating" [
              set newitem heating-system-cost-advice self broken-appliance
            ]
            [
              set newitem gain-ess-choose-replacement broken-appliance
            ]
          ]
          [
            set newitem sustain-ess-choose-replacement broken-appliance
            biospheric-boost [cost-this-step] of newitem
          ]
        ]
        ifelse newitem != false and is-agent? newitem and newitem != nobody [
          add-item newitem 0
        ]
        [
          output-print (word "*** Warning: household \"" household-id
            "\" could not replace essential appliance \"" [name] of broken-appliance "\"")
          set breakdown-list (fput broken-appliance breakdown-list)
        ]
      ]
    ]
    [
      set breakdown-list (fput broken-appliance breakdown-list)
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; buy-insulation
;;
;; Buy insulation (sustain and gain goal-frames only).

to buy-insulation
  ifelse goal-frame = "gain" [
    gain-insulation
  ]
  [
    sustain-insulation
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; update-wish-list
;;
;; Update the wish list for appliances, given a list of visits made.

to update-wish-list [visited]
  ;; Choose random items with a subcategory introduced in the last
  ;; new-subcategory-steps.
  let new-subcategory-appliances-to-choose new-subcategory-appliances-per-step
  let new-appliance-list shuffle sort current-appliances with
    [member? subcategory new-subcategories and not (category = "heating") and
      not my-member? self ([out-ownership-neighbors] of myself)]
  while [length new-appliance-list > 0 and new-subcategory-appliances-to-choose > 0] [
    set wish-list fput (first new-appliance-list) wish-list
    set new-subcategory-appliances-to-choose new-subcategory-appliances-to-choose - 1
    set new-appliance-list but-first new-appliance-list
  ]

  ;; Choose one random item from each of visits-per-step social links to add to wish-list.
  ;; Note that multiple visits may have been made to the same social-link-neighbor.
  foreach visited [
    let unowned-appliance (one-of ((appliances-i-dont-have-owned-by ?) with [not (category = "heating")]))
    if unowned-appliance != nobody [
      set wish-list fput unowned-appliance wish-list
        ;; It doesn't matter if an appliance occurs more than once in the wish-list.
    ]
  ]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; update-insulation-upgrades
;;
;; Use the information loaded from the insulation upgrade file to update the
;; insulation upgrades available.

to update-insulation-upgrades
  let next-update false
  if length insulation-updates > 0 [
    set next-update first insulation-updates
  ]
  while [ next-update != false ] [
     ifelse read-from-string (table:get next-update "step") = ticks + 1 [
       update-insulation next-update

       set insulation-updates but-first insulation-updates
       ifelse length insulation-updates > 0 [
         set next-update first insulation-updates
       ]
       [
         set next-update false
       ]
     ]
     [
       set next-update false
     ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; update-insulation
;;
;; Implement an insulation update command.

to update-insulation [cmd]
  let command table:get cmd "command"
  let dw-type table:get cmd "dwelling-type"
  let from-state insulations with [insulation-state = table:get cmd "from-state" and insulation-dwelling-type = dw-type]
  let to-state insulations with [insulation-state = table:get cmd "to-state" and insulation-dwelling-type = dw-type]
  let the-cost read-from-string table:get cmd "cost"

  if count from-state != 1 [
    output-print (word "*** Error in insulation update file " insulation-update-file
      ": not 1 insulation for state " (table:get cmd "from-state")
       " and dwelling type " dw-type)
  ]

  if count to-state != 1 [
    output-print (word "*** Error in insulation update file " insulation-update-file
      ": not 1 insulation for state " (table:get cmd "to-state")
       " and dwelling type " dw-type)
  ]


  ifelse command = "remove" [
    ask from-state [
      ask out-upgrade-to one-of to-state [
        die
      ]
    ]
  ]
  [
    ifelse command = "add" [
      ask from-state [
        create-upgrades-to to-state [
          set upgrade-cost the-cost
          set hidden? true
        ]
      ]
    ]
    [
      ifelse command = "change" [
        ask from-state [
          ask out-upgrade-to one-of to-state [
            set upgrade-cost the-cost
          ]
        ]
      ]
      [
        output-print (word "*** Warning: Ignoring unrecognised insulation "
          "upgrade update command \"" command "\"")
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; get-usage-mode
;;
;; Return the usage-mode for a household.

to-report get-usage-mode
  let mode []
  let mode-boolean table:make

  let frame-table table:get usage-mode-matrix goal-frame

  foreach (table:keys frame-table) [
    let condition-str table:get frame-table ?
    let condition-not false

    let condition-words split " " condition-str

    if first condition-words = "not" [
      set condition-not true
      set condition-words but-first condition-words
    ]

    let condition first condition-words

    if condition = "negative-capital-reserve" [
      ifelse negative-capital-reserve [
        add-mode mode-boolean ? condition-not
      ]
      [
        add-mode mode-boolean ? (not condition-not)
      ]
    ]
    if condition = "true" [
      add-mode mode-boolean ? condition-not
    ]
    if condition = "false" [
      add-mode mode-boolean ? (not condition-not)
    ]

    ;; Add new rules here.
  ]

  foreach (table:keys mode-boolean) [
    if table:get mode-boolean ? = true [
      set mode fput ? mode
    ]
  ]

  if length mode > 1 [
    output-print (word "*** Error: ambiguous usage-mode for agent with goal-frame \""
      goal-frame "\": " mode)
  ]
  if length mode = 0 [
    output-print (word "*** Error: no usage-mode for agent with goal-frame \"" goal-frame "\"")
  ]

  report one-of mode
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; add-mode
;;
;; Add a mode to the usage-mode boolean table.

to add-mode [mode-table mode boolean]
  if table:has-key? mode-table mode [
    if not (table:get mode-table mode = boolean) [
      output-print (word "*** Error: conflict for usage-mode \"" mode "\" in agent with "
        "goal frame \"" goal-frame "\"")
    ]
  ]
  table:put mode-table mode boolean
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; calculate-moeu
;;
;; Calculate the overall energy use of a household for the current step. This
;; procedure also deducts the price of that energy from household captial-reserve.

to calculate-moeu
  let moeu 0 ;; This is in kWh for gas and oil as well as electricity.
  let ecost 0
  let hh-type household-type
  let dw-type [dwelling-type] of one-of out-address-neighbors
  let t-type [tenure] of one-of out-address-neighbors
  let umode usage-mode
  let my-insulation [insulation-factor] of one-of out-address-neighbors

  if count out-ownership-neighbors = 0 [
    output-print (word "*** Error: household \"" household-id "\" has no appliances ")
  ]

  ask out-ownership-neighbors [
    let consumptions out-consume-neighbors with [for-household-type = hh-type
      and for-dwelling-type = dw-type
      and for-tenure-type = t-type
      and in-usage-mode = umode
      and in-step = (ticks mod steps-per-year) + 1]
    if count consumptions = 0 [
      output-print (word "*** Error: appliance \"" name
        "\" doesn't use any consumption pattern for household type \"" hh-type
        "\", dwelling type \"" dw-type "\", tenure type \"" t-type
        "\", usage-mode \"" umode "\" and step " ((ticks mod steps-per-year) + 1))
    ]

    ask consumptions [
      ;; For each fuel used by the appliance for any purpose this step.
      let cons-ins-factor 1
      if for-purpose = "space-heating" [
        set cons-ins-factor my-insulation
      ]
      ask my-out-uses [
        let the-fuel other-end
        let energy-use (units-per-use * cons-ins-factor * [kWh-per-unit] of the-fuel)

        ask the-fuel [
          set total-kWh total-kWh + energy-use
        ]

        set moeu moeu + energy-use
        set ecost ecost + (units-per-use * cons-ins-factor * table:get energy-price [fuel-type] of the-fuel)
      ]
    ]
  ]

  set steps-total-energy-use moeu
  set capital-reserve capital-reserve - ecost
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; calculate-current-running-cost
;;
;; An appliance reports its running cost (for fuel use) based on current prices.

to-report calculate-current-running-cost [hh a-step]
  let hh-type [household-type] of hh
  let hh-dwelling one-of ([out-address-neighbors] of hh)
  let dw-type [dwelling-type] of hh-dwelling
  let t-type [tenure] of hh-dwelling
  let umode [usage-mode] of hh
  let dw-ins-factor [insulation-factor] of hh-dwelling

  let consumptions out-consume-neighbors with [for-household-type = hh-type
    and for-dwelling-type = dw-type
    and for-tenure-type = t-type
    and in-usage-mode = umode
    and in-step = (a-step mod steps-per-year) + 1]

  if count consumptions = 0 [
    output-print (word "*** Error: appliance \"" name
      "\" doesn't use any consumption pattern for household type \"" hh-type
      "\", dwelling type \"" dw-type "\", tenure type \"" t-type
      "\", usage-mode \"" umode "\" and step " ((a-step mod steps-per-year) + 1))
  ]

  let total-cost 0

  ask consumptions [
    ;; For each fuel used by the appliance for any purpose during this step
    ;; (cookers can use electricity for the oven and gas for the hub).
    let cons-ins-factor 1
    if for-purpose = "space-heating" [
      set cons-ins-factor dw-ins-factor
    ]
    ask my-out-uses [
      let the-fuel other-end

      set total-cost total-cost + (units-per-use * cons-ins-factor * table:get energy-price [fuel-type] of the-fuel)
    ]
  ]

  report total-cost
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; calculate-projected-running-cost
;;
;; Calculate running cost of an appliance over a household's planning horizon,
;; assuming current energy prices. Note that this is currently used only for
;; heating systems (called from heating-system-cost-advice, itself called from
;; replace-broken-appliances).

to-report calculate-projected-running-cost [hh]
  let hh-horizon [planning-horizon] of hh

  let total-cost 0

  let a-step ticks

  repeat hh-horizon [
    set a-step a-step + 1
    set total-cost total-cost + calculate-current-running-cost hh a-step
  ]

  report total-cost
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; calculate-finance
;;
;; Calculate the household's financial position.

to calculate-finance
  set capital-reserve (capital-reserve + income-this-step)
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; calculate-breakdowns
;;
;; Calculate the breakdowns of appliances.

to calculate-breakdowns
  ask households [
    ask my-out-ownerships [
      if random-float 1 < [breakdown-probability] of other-end [
        set broken? true
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; choose-goal-frame
;;
;; Choose a goal-frame, and adjust value-strength parameters to reflect the
;; influence of habit.

to-report choose-goal-frame
  let value-strengths-total hedonic + egoistic + biospheric
  let selection random-float value-strengths-total
  ifelse (selection < hedonic) [
    set hedonic hedonic + habit-adjustment-factor
    ifelse hedonic > value-strengths-total [
      set hedonic value-strengths-total
      set egoistic 0
      set biospheric 0
    ]
    [
      set egoistic egoistic - (habit-adjustment-factor / 2)
      set biospheric biospheric - (habit-adjustment-factor / 2)
      ifelse egoistic < 0 [
        set biospheric value-strengths-total - hedonic
        set egoistic 0
      ]
      [
        if biospheric < 0 [
          set egoistic value-strengths-total - hedonic
          set biospheric 0
        ]
      ]
    ]
    report "enjoy"
  ]
  [
    ifelse (selection < hedonic + egoistic) [
      set egoistic egoistic + habit-adjustment-factor
      ifelse egoistic > value-strengths-total [
        set egoistic value-strengths-total
        set hedonic 0
        set biospheric 0
      ]
      [
        set hedonic hedonic - (habit-adjustment-factor / 2)
        set biospheric biospheric - (habit-adjustment-factor / 2)
        ifelse hedonic < 0 [
          set biospheric value-strengths-total - egoistic
          set hedonic 0
        ]
        [
          if biospheric < 0 [
            set hedonic value-strengths-total - egoistic
            set biospheric 0
          ]
        ]
      ]
      report "gain"
    ]
    [
      set biospheric biospheric + habit-adjustment-factor
      ifelse biospheric > value-strengths-total [
        set biospheric value-strengths-total
        set hedonic 0
        set egoistic 0
      ]
      [
        set hedonic hedonic - (habit-adjustment-factor / 2)
        set egoistic egoistic - (habit-adjustment-factor / 2)
        ifelse hedonic < 0 [
          set egoistic value-strengths-total - biospheric
          set hedonic 0
        ]
        [
          if egoistic < 0 [
            set hedonic value-strengths-total - biospheric
            set egoistic 0
          ]
        ]
      ]
      report "sustain"
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; adjust-goal-frame
;;
;; Change goal-frame, with a specified probability,
;; if any "trigger" conditions are met. Repeated
;; changes may occur during this process.

to adjust-goal-frame
  let tr-list shuffle triggers-list
  let tr-num 0
  let use-tr false
  foreach tr-list [
    set tr-num first ?
    ifelse (tr-num = 1) [
      if (capital-reserve < income-this-step * item 1 ?) [
        set use-tr true
      ]
    ]
    [
      ifelse (tr-num = 2) [
        if (capital-reserve > income-this-step * item 1 ?) [
          set use-tr true
        ]
      ]
      [
        ifelse (tr-num = 3) [
          if (ticks > 0 and heating-fuel-price-ratio-change > item 1 ?) [
            set use-tr true
          ]
        ]
        [
          ifelse (tr-num = 4) [
            if (ticks > 0 and heating-fuel-price-ratio-change < item 1 ?) [
              set use-tr true
            ]
          ]
          ;; Additional trigger-types can be added here.
          [
            output-print (word "*** Error: unmatched trigger-number" tr-num)
          ]
        ]
      ]
    ]
    if (use-tr and goal-frame = item 2 ?) [
      if (random-float 1 < item 4 ?) [
        set goal-frame item 3 ?
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; heating-fuel-price-ratio-change
;;
;; Report the ratio of the price of a household's heating-fuel this time-step to
;; the price of the same fuel last time-step. Note that "hs-fuel" may be either
;; space-heating fuel or water-heating fuel, but these are at present always the
;; same physical "fuel" (gas, electricity or oil), at the same price.


to-report heating-fuel-price-ratio-change
  let  hs one-of out-ownership-neighbors with [category = "heating"]
  let hs-fuel false
  ask hs [
    let consump one-of out-consume-neighbors
    ask consump [
      ask one-of my-out-uses [
        set hs-fuel [fuel-type] of other-end
      ]
    ]
  ]
  report (table:get energy-price hs-fuel) /
    (table:get (item (ticks - 1) energy-price-list) hs-fuel)
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; insulation-factor
;;
;; Return the insulation factor of a dwelling (higher factors mean poorer insulation
;; and hence greater enerfgy use for space-heating).

to-report insulation-factor
  let ins-factor false
  ask (one-of in-insulate-neighbors) [
  ;; There will only be one.
    set ins-factor fuel-use-factor
  ]
  report ins-factor
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; current-replacements-for
;;
;; Report a NetLogo agent-set of the appliances that can replace the argument.

to-report current-replacements-for [an-appliance]
  report current-appliances with [self = an-appliance
    or my-member? self ([out-replacement-neighbors] of an-appliance)]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; cost-this-step
;;
;; Report the cost of an appliance in the current time-step.

to-report cost-this-step
  let indexa ticks - first-step-available
  if (first-step-available = -1) [
    set indexa (indexa - 1)
  ]
  ;; Note that if the item is not yet available or no longer available, or if
  ;; the cost-list has fewer items than the number of ticks for which it is available,
  ;; the last element of the cost-list will be returned.
  if (indexa < 0) or (length cost-list - 1 < indexa) [
    set indexa (length cost-list - 1)
  ]
  report item indexa cost-list
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; income-this-step
;;
;; Report a household's income this time-step.

to-report income-this-step
  let indexa ticks
  if (length steply-net-income - 1 < indexa) [
    set indexa (length steply-net-income - 1)
  ]
  report item indexa steply-net-income
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; current-replacements-for-appliances-to-be-replaced
;;
;; Return a NetLogo agent-set of appliances that could replace any broken appliances
;; of the household passed as argument.

to-report current-replacements-for-appliances-to-be-replaced [hh]
  let breakdown-set appliances with [my-member? self ([breakdown-list]
    of hh)]
  report current-appliances with
    [my-member? self ([out-replacement-neighbors] of breakdown-set)
      or my-member? self breakdown-set]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; appliances-i-dont-have-owned-by
;;
;; Report a NetLogo agent-set of appliances not owned by the household that another
;; household they visited does have.

to-report appliances-i-dont-have-owned-by [some-one-i-visited]
  report ([out-ownership-neighbors] of some-one-i-visited) with
    [not my-member? self ([out-ownership-neighbors] of myself)]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; visit
;;
;; Visit another household; this involves goal-frame adjustment for the visitor,
;; and possibly for the visited household.

to visit [some-one]
  ask social-link-with some-one [
    set n-visits n-visits + 1
  ]
  ;; Adjust values under the influence of those of the social link neighbour.
  value-adjust some-one

  if (reciprocal-adjustment = true) [
    ;; Adjust contact's values reciprocally.
    ask some-one [value-adjust myself]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; enjoy-ess-choose-replacement
;;
;; Replace a piece of essential equipment in enjoy mode. If acting
;; hedonistically (if goal-frame is enjoy), a household's choice is unpredictable,
;; so a random selection is made.

to-report enjoy-ess-choose-replacement [an-appliance]
  report one-of (current-replacements-for an-appliance)
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; heating-system-cost-advice
;;
;; Procedure representing the provision of advice to a household as to the
;; lowest financial cost option for replacing a heating system, based on its
;; expected energy use over the household's planning horizon.

to-report heating-system-cost-advice [hh heating-system]
  let app-replacements current-replacements-for heating-system

  if count app-replacements = 0 [
    output-print (word "*** Error: heating-system \"" [name] of heating-system
      "\" has no current replacement \"")
    report false
  ]

  let best-cost -1
  let best-app false

  ask app-replacements [
    let this-cost cost-this-step + calculate-projected-running-cost hh
    ifelse best-cost = -1 [
      set best-app self
      set best-cost this-cost
    ]
    [
      if this-cost < best-cost [
        set best-app self
        set best-cost this-cost
      ]
    ]
  ]

  report best-app
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; gain-ess-choose-replacement
;;
;; Replace a piece of essential equipment in gain goal-frame. This is based on purchase
;; cost and running cost.

to-report gain-ess-choose-replacement [an-appliance]
  report one-of ((current-replacements-for an-appliance) with-min [gain-cost])
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; sustain-ess-choose-replacement
;;
;; Replace a piece of essential equipment in sustain goal-frame. Choice of replacement
;; is based on minimising environmental cost.

to-report sustain-ess-choose-replacement [an-appliance]
  report one-of ((current-replacements-for an-appliance) with-min [sustain-cost])
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; gain-cost
;;
;; Report the gain cost of an appliance. This is just its purchase price.

to-report gain-cost
  report cost-this-step
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; sustain-cost
;;
;; Report the environmental cost of an appliance. This is given by the CEDSS
;; representation of its energy-rating (better ratings are given lower numbers)
;; or if that is not available, by its breakdown probability.

to-report sustain-cost
  ifelse energy-rating-provided? [
    report energy-rating
  ]
  [
    report breakdown-probability
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; enjoy-equip-nonessential
;;
;; Purchase new non-essential appliances in enjoy goal-frame.

to enjoy-equip-nonessential
  let choice-list (shuffle wish-list)
  foreach breakdown-list [
    let crf sort current-replacements-for ?
    if (crf != []) [
      set choice-list (sentence (one-of crf) choice-list)
    ]
  ]
  ;; Sort in *descending* order of hedonic score (this currently has no effect
  ;; as all items have the same hedonic score).
  if length (choice-list) > 1 [
    set choice-list sort-by [
      ([hedonic-score] of ?1) > ([hedonic-score] of ?2)
    ] choice-list
  ]

  let affordable-choice-list []
  foreach choice-list [
    if [cost-this-step] of ? < capital-reserve + (income-this-step * credit-multiple-limit) [
    ;; The credit-multiple-limit allows the household to borrow if positive. If negative, (when
    ;; it can also be referred to as the capital-minimum), it requires a minimum, positive level
    ;; of liquid capital to be maintained for non-essential purchases to be made here.
      set affordable-choice-list lput ? affordable-choice-list
    ]
  ]
  ;; Buy as many affordable things as possible, but not more than one from a category.
  while [length affordable-choice-list > 0] [
    let new-item first affordable-choice-list
    add-item new-item 0
    ;; Update the list of affordable things.
    let new-choice-list []
    foreach but-first affordable-choice-list [
      if ([category] of ? != [category] of new-item) and
        ([cost-this-step] of ? < capital-reserve + (income-this-step * credit-multiple-limit)) [
        set new-choice-list lput ? new-choice-list
      ]
    ]
    set affordable-choice-list new-choice-list
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; gain-equip-nonessential
;;
;; Purchase a new non-essential appliance in gain goal-frame.

to gain-equip-nonessential
  let choice-set current-replacements-for-appliances-to-be-replaced self
  add-item (one-of choice-set with-min [gain-cost]) 0
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; sustain-equip-nonessential
;;
;; Purchase a new non-essential appliance in sustain goal-frame.

to sustain-equip-nonessential
  let choice-set current-replacements-for-appliances-to-be-replaced self
  let newitem one-of choice-set with-min [sustain-cost]
  add-item newitem 0
  if (newitem != nobody) [
    biospheric-boost [cost-this-step] of newitem
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; gain-insulation
;;
;; Add insulation in gain goal-frame.

to gain-insulation
  ;; Find the insulation upgrade from the current state that will save
  ;; as much money as possible over the planning horizon. If it will
  ;; make a positive saving, apply it.
  let current-insulation false
  let current-fuel-use-factor false
  let dw one-of out-address-neighbors
  ask dw [
    set current-insulation (one-of in-insulate-neighbors)
    ;; There will be only one.
    set current-fuel-use-factor insulation-factor
  ]
  let new-insulation false
  let cost-of-upgrade 0
  let saving 0
  let candidate-fuel-use-factor 0
  let candidate-cost 0
  let candidate-saving 0
  let current-projected-space-heating-cost calculate-projected-space-heating-cost-over-planning-horizon self
  ;; Here "self" is the household.
  ask current-insulation [
    ask my-out-upgrades [
      set candidate-cost upgrade-cost
      ask other-end [
        set candidate-fuel-use-factor fuel-use-factor
        set candidate-saving (current-projected-space-heating-cost * (1 - candidate-fuel-use-factor / current-fuel-use-factor) - candidate-cost)
        if (candidate-saving > saving) [
          set saving candidate-saving
          set new-insulation self
          set cost-of-upgrade candidate-cost
        ]
      ]
    ]
  ]
  if new-insulation != false [
    add-insulation dw current-insulation new-insulation cost-of-upgrade
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; sustain-insulation
;;
;; Add insulation in sustain goal-frame.

to sustain-insulation
  ;; Find the insulation upgrade from the current state that will
  ;; leave a positive capital-reserve and save the most energy. If there is one
  ;; that will save energy, apply it.
  let dw one-of out-address-neighbors
  let c-r capital-reserve
  let current-insulation false
  let current-fuel-use-factor false
  ask dw [
    set current-insulation one-of in-insulate-neighbors
    ;; There will be only one.
    set current-fuel-use-factor insulation-factor
  ]
  let new-insulation false
  let cost-of-upgrade 0
  let candidate-cost 0
  let energy-saving-ratio 1
  let candidate-energy-saving-ratio 1
  ask current-insulation [
    ask my-out-upgrades with [upgrade-cost <= c-r] [
      set candidate-cost upgrade-cost
      ask other-end [
        set candidate-energy-saving-ratio fuel-use-factor / current-fuel-use-factor
        if (candidate-energy-saving-ratio < energy-saving-ratio) [
          set energy-saving-ratio candidate-energy-saving-ratio
          set new-insulation self
          set cost-of-upgrade candidate-cost
        ]
      ]
    ]
  ]
  if (energy-saving-ratio < 1) [
    add-insulation dw current-insulation new-insulation cost-of-upgrade
    biospheric-boost cost-of-upgrade
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; biospheric-boost
;;
;; Strengthens biospheric values as a result of taking a pro-environmental
;; action.

to biospheric-boost [amount-spent]
  let value-strength-total biospheric + hedonic + egoistic
  if (amount-spent > biospheric-boost-ceiling) [
    set amount-spent biospheric-boost-ceiling
  ]
  let boost amount-spent * biospheric-boost-factor * 0.0001
  ifelse (biospheric + boost > value-strength-total) [
    set biospheric value-strength-total
    set hedonic 0
    set egoistic 0
  ]
  [
    set biospheric biospheric + boost
    ifelse (boost / 2 > hedonic) [
      set hedonic 0
      set egoistic value-strength-total - biospheric
    ]
    [
      ifelse (boost / 2 > egoistic) [
        set egoistic 0
        set hedonic value-strength-total - biospheric
      ]
      [
        set hedonic hedonic - boost / 2
        set egoistic egoistic - boost / 2
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; calculate-projected-space-heating-cost-over-planning-horizon
;;
;; Calculates the projected cost of space-heating for a dwelling
;; over the household's planning horizon.

to-report calculate-projected-space-heating-cost-over-planning-horizon [hh]
  let hh-horizon [planning-horizon] of hh
  let total-cost 0
  let a-step ticks
  repeat hh-horizon [
    set a-step a-step + 1
    set total-cost total-cost + calculate-current-space-heating-cost hh a-step
  ]
  report total-cost
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; calculate-current-space-heating-cost
;;
;; Calculates the actual or projected cost of space-heating of a dwelling
;; for a specific time-step, assuming current heating costs and no insulation.

to-report calculate-current-space-heating-cost [hh a-step]
  let hh-type [household-type] of hh
  let hh-dwelling one-of ([out-address-neighbors] of hh)
  let dw-type [dwelling-type] of hh-dwelling
  let t-type [tenure] of hh-dwelling
  let umode [usage-mode] of hh
  let hs one-of out-ownership-neighbors with [category = "heating"]
  let current-cost 0
  ask hs [
    let consumption one-of out-consume-neighbors with [for-household-type = hh-type
    and for-dwelling-type = dw-type
    and for-tenure-type = t-type
    and for-purpose = "space-heating"
    and in-usage-mode = umode
    and in-step = (a-step mod steps-per-year) + 1]

    if consumption = nobody [
      output-print (word "*** Error: heating-system \"" name
        "\" doesn't perform space-heating for household type \"" hh-type
        "\", dwelling type \"" dw-type "\", tenure type \"" t-type
        "\", usage-mode \"" umode "\" and step " ((a-step mod steps-per-year) + 1))
    ]

    ask consumption [
      ask my-out-uses [
        let the-fuel other-end
        set current-cost units-per-use * [insulation-factor] of (one-of [out-address-neighbors] of hh)
          * table:get energy-price [fuel-type] of the-fuel
      ]
    ]
  ]
  report current-cost
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; add-insulation
;;
;; Adds insulation to a dwelling.

to add-insulation [dw old-insulation new-insulation cost-of-upgrade]
  if new-insulation != nobody [
    add-insulation-cost-free dw old-insulation new-insulation
    set capital-reserve (capital-reserve - cost-of-upgrade)
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; add-insulation-cost-free
;;
;; Adds insulation to a dwelling without subtracting the cost from capital-reserve.
;; Currently, landlords do not insulate, so this will always be called from add-insulation.

to add-insulation-cost-free [dw old-insulation new-insulation]
  if (new-insulation != nobody) [
    ask dw [
      ask my-in-insulates with [other-end = old-insulation] [
        die
      ]
      create-insulate-from new-insulation [
        set hidden? true
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; add-item
;;
;; Add an appliance to a household.

to add-item [new-item vintage]
  if (new-item != nobody) [
    add-item-cost-free new-item vintage
    ;; Vintage allows for the possibility of items being old at the start of a
    ;; run, or of acquiring second-hand items.
    set capital-reserve (capital-reserve - [cost-this-step] of new-item)
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; add-item-cost-free
;;
;; Add a piece of equipment to a household, without subtracting the cost from capital-reserve.

to add-item-cost-free [new-item vintage]
  if(new-item != nobody) [
    let category1 [category] of new-item
    let hh-type [household-type] of self
    if (table:has-key? maximum-in-category-table hh-type) [
      let hh-type-table table:get maximum-in-category-table hh-type
      if (table:has-key? hh-type-table category1) [
        let category1-ownership-list []
        ask (my-out-ownerships with [[category] of other-end = category1]) [
          set category1-ownership-list fput self category1-ownership-list
        ]
        if (length category1-ownership-list + 1 > table:get hh-type-table category1) [
          let sorted-list sort-by [[age] of ?1 > [age] of ?2] category1-ownership-list
          ask first sorted-list [
            set land-fill fput other-end land-fill
            die
          ]
        ]
      ]
    ]

    create-ownership-to new-item [
      set hidden? true
      set broken? false
      set age vintage
    ]

    let updated-breakdown-list []
    foreach breakdown-list [
      if(? != new-item and not (my-member? ? [in-replacement-neighbors] of new-item)) [
      ;; Note that in-replacement-neighbours of an item are appliancess it can replace.
      ;; Note that the new-item could replace more than one broken appliance.
        set updated-breakdown-list fput ? updated-breakdown-list
      ]
    ]
    set breakdown-list updated-breakdown-list

    let updated-wish-list []
    foreach wish-list [
      if(? != new-item and not (my-member? ? [in-replacement-neighbors] of new-item)) [
        set updated-wish-list fput ? updated-wish-list
      ;; Note that the new-item could displace more than one wished-for item.
      ]
    ]
    set wish-list updated-wish-list

    set steps-total-energy-use (steps-total-energy-use + [embodied-energy] of new-item)
    ;; Currently, this is always 0; embodied-energy has not been implemented.
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; update-links
;;
;; Update the social links of a household.

to update-links
  ifelse (random 2 = 1) [
    lose-link
  ]
  [
    gain-link
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; lose-link
;;
;; A household drops a social link.

to lose-link
  if (count social-link-neighbors > 0) [
    let weak-contacts (social-link-neighbors with-min
      [appliance-similarity out-ownership-neighbors [out-ownership-neighbors] of myself])

    set weak-contacts (weak-contacts with-max [block-distance [pxcor] of patch-here
      [pycor] of patch-here])

    let lose-contact one-of (weak-contacts with-min [[n-visits] of social-link-with myself])
    let link-to-lose (social-link-with lose-contact)
    ask link-to-lose [die]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; block-distance
;;
;; Report the block distance from the household to the *patch* co-ordinates
;; supplied as argument (bearing in mind that now multiple households can occupy
;; a patch, with randomly assigned coordinates).

to-report block-distance [x y]
  report (abs ([pxcor] of patch-here - x) + abs ([pycor] of patch-here - y))
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; gain-link
;;
;; Let a household gain a social link, provided it does not already have the
;; maximum number allowed. The household first selects one of those it is linked
;; to, and most similar to in terms of what the two own. If any of that household's
;; other social-link-neighbours are not among its own, it chooses one to link to.
;; If this process does not produce a new social-link, it links at random to a household
;; it is not already linked to.
;; Note that the model parameter max-links is not a hard limit on the number of social links
;; a household may have, as gain-link does not check that the household it selects to link
;; to has less than max-links social links before the new link in created. However, no household
;; will take the initiative in forming a new social link when it already has max-links or more.

to gain-link
  if (count social-link-neighbors < max-links) [
    let choose-from []
    let strong-contacts (social-link-neighbors with-max
      [appliance-similarity out-ownership-neighbors [out-ownership-neighbors]
        of myself])

    if (count strong-contacts > 0) [
      let intermediate (one-of strong-contacts)

      let poss-new-contacts shuffle (sort (other ([link-neighbors]
        of intermediate)))

      foreach poss-new-contacts [
        if (member? ? social-link-neighbors = false) [
          set choose-from (fput ? choose-from)
        ]
      ]
    ]
    if (choose-from = []) [
      let slms sort social-link-neighbors
      ask other households [
        if (my-member? self slms) = false [
          set choose-from (fput self choose-from)
        ]
      ]
    ]
    if (choose-from != []) [
      create-social-link-with (one-of choose-from) [
        set n-visits 0
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; value-adjust
;;
;; Adjust the value strengths of the household in relation to another household.

to value-adjust [contact]
  set hedonic hedonic + (frame-adjustment * ([hedonic] of contact - hedonic))

  set egoistic egoistic + (frame-adjustment
    * ([egoistic] of contact - egoistic))

  set biospheric biospheric +
    (frame-adjustment * ([biospheric] of contact - biospheric))

  ;; The next three lines should only be needed if frame-adjustment
  ;; is either > 1 or < 0.
  set hedonic ifelse-value (hedonic < 0) [0] [hedonic]
  set egoistic ifelse-value (egoistic < 0) [0] [egoistic]
  set biospheric ifelse-value (biospheric < 0) [0] [biospheric]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; absorb-external-influences
;;
;; Adjust the value strengths of the household in relation to external influences.

to absorb-external-influences
  let adjustment 0
  foreach external-influences-list [
    if ((item 0 ? = ticks) and (item 1 ? = goal-frame)) [
      set adjustment last ?
      ifelse (item 2 ? = "hedonic") [
        ifelse hedonic < adjustment [
          set adjustment hedonic
          set hedonic 0
        ]
        [
          set hedonic hedonic - adjustment
        ]
        ifelse (item 3 ? = "egoistic") [
          set egoistic egoistic + adjustment
        ]
        [
          set biospheric biospheric + adjustment
        ]
      ]
      [
        ifelse (item 2 ? = "egoistic") [
          ifelse egoistic < adjustment [
            set adjustment egoistic
            set egoistic 0
          ]
          [
            set egoistic egoistic - adjustment
          ]
          ifelse (item 3 ? = "hedonic") [
            set hedonic hedonic + adjustment
          ]
          [
            set biospheric biospheric + adjustment
          ]
        ]
        [
          ifelse biospheric < adjustment [
            set adjustment biospheric
            set biospheric 0
          ]
          [
            set biospheric biospheric - adjustment
          ]
          ifelse (item 3 ? = "hedonic") [
            set hedonic hedonic + adjustment
          ]
          [
            set egoistic egoistic + adjustment
          ]
        ]
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; appliance-similarity
;;
;; Report a measure of the similarity of two lists of equipment cea and ceb.

to-report appliance-similarity [cea ceb]
  let shared appliances with [my-member? self cea and my-member? self ceb]
  let unshared appliances with [(my-member? self cea or my-member? self ceb)
    and not my-member? self shared]
  report count (shared) - count (unshared)
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; intersection
;;
;; Report the intersection of two lists.

to-report intersection [list1 list2]
  let outlist []
  foreach list1 [
    if (member? ? list2) [
      set outlist (fput ? outlist)
    ]
  ]
  report outlist
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; profile-setup
;;
;; Report the time used to set up the simulation.

to-report profile-setup
  report profiler:inclusive-time "setup"
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; profile-go
;;
;; Report the time used to run the simulation (other than setting up).

to-report profile-go
  report profiler:inclusive-time "go"
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; show-changes
;;
;; Provide some graphical visualisation of the status of a household.

to show-changes
  if max-energy-display > 0 [
    ask households [
      ifelse capital-reserve < 0 [
        set shape "face sad"
      ]
      [
        set shape "face happy"
      ]
      ifelse goal-frame = "enjoy" [
        set color red
      ]
      [
        ifelse goal-frame = "gain" [
          set color blue
        ]
        [
          ifelse goal-frame = "sustain" [
            set color green
          ]
          [
            set color yellow
          ]
        ]
      ]
    ]
    ;; The following lines have been altered to allow empty properties to exist.
    ;; However, this facility has not yet been used.
    ask dwellings [
      ifelse (one-of in-address-neighbors != nobody) [
        let kwh [steps-total-energy-use] of one-of in-address-neighbors
        ifelse kwh >= max-energy-display [
          set color white
        ]
        [
          let ncol array:length dwelling-temp-colours
          let index int ((kwh * ncol) / max-energy-display)
          set color array:item dwelling-temp-colours index
        ]
      ]
      [set color gray
      ]
    ]

    ask social-links [
      set color ifelse-value (n-visits > 19) [ 9.9 ] [ n-visits / 2 ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                                            ;;
;; CEDSS File I/O                                                             ;;
;;                                                                            ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; read-table
;;
;; Read a table from a CSV file in the format key, value, with one pair per line;
;; value may be anything NetLogo can build from a string.

to-report read-table [table-file]
  let table table:make
  file-open table-file
  while [not file-at-end?] [
    let line file-read-line
    let data (split "," line)
    let key (first data)
    set data (but-first data)
    let value (first data)
    table:put table key value
  ]
  file-close
  report table
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; read-csv-with-headings
;;
;; Read a CSV file, returning a list of rows, each item in the list a table
;; with keys taken from the first row and entries from one of the remaining rows.

to-report read-csv-with-headings [csv-file]
  let rows []
  file-open csv-file
  let headings (split "," file-read-line)

  let row 1
  while [not file-at-end?] [
    let line split "," file-read-line

    if length line != length headings [
      output-print (word "*** Error in file " csv-file ": there are "
        length headings " headings, and " length line " entries in row " row)
    ]

    let row-table table:make
    (foreach headings line [
      table:put row-table ?1 ?2
    ])
    set rows lput row-table rows
    set row row + 1
  ]
  file-close

  report rows
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; read-matrix
;;
;; Read a simple matrix with row and column headings and string entries. The
;; result returned is a table of tables. Use the row heading to access the
;; table from which the column heading name is used to access the entry. For
;; example:
;;
;; table:get (table:get result-of-this-procedure "row-heading") "column-heading"

to-report read-matrix [csv-file]
  let matrix-table table:make

  file-open csv-file
  let headings array:from-list (split "," file-read-line)

  while [not file-at-end?] [
    let line array:from-list (split "," file-read-line)
    let row-table table:make
    let i 1
    while [i < array:length line] [
      table:put row-table (array:item headings i) (array:item line i)
      set i i + 1
    ]
    table:put matrix-table (array:item line 0) row-table
  ]
  file-close
  report matrix-table
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; read-numeric-ts-matrix
;;
;; Read in a time series of matrices, each of which has a matching set of row
;; and column headings, with a list of extra columns. See the Information tab
;; (household transition matrix file) for more information. The result is a
;; list of tables of tables.

to-report read-numeric-ts-matrix [csv-file extra-cols]
  let table-list []

  file-open csv-file

  let last-step 0
  while [not file-at-end?] [
    let matrix-table table:make

    let headings array:from-list (split "," file-read-line)

    let tstep read-from-string (array:item headings 0)

    if tstep != last-step + 1 [
      output-print (word "*** Error in transition matrix time-series file " csv-file
        ": matrix for step " tstep " is not the next one after " last-step)
    ]

    set last-step tstep

    let row 1
    while [not file-at-end? and row < array:length headings - length extra-cols] [
      let line array:from-list (split "," file-read-line)
      let row-table table:make
      if (array:item headings row) != (array:item line 0) [
        output-print (word "*** Error in transition matrix time-series file " csv-file
          ": row heading \"" (array:item line 0) "\" does not match column heading \""
          (array:item headings row) "\"")
      ]
      let i 1
      while [i < array:length line] [
        table:put row-table (array:item headings i) (read-from-string (array:item line i))
        set i i + 1
      ]
      table:put matrix-table (array:item headings row) row-table
    ]

    set table-list fput matrix-table table-list
  ]
  file-close
  report table-list
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; read-patch-layout [filename]
;;
;; The patch layout file is a CSV file, which specifies the type of each
;; patch. If the type is 'dwelling', then a dwelling agent is sprouted at that
;; patch, and the patch may have several dwellings on it.

to read-patch-layout [filename]
  if filename != false and filename != "null" and length filename > 0 [
    file-open filename
    while [not file-at-end?] [
      let data (array:from-list (split-no-null "," file-read-line))

      let x read-from-string array:item data 0
      let y read-from-string array:item data 1
      let ptype array:item data 2

      ask patch x y [
        set pcolor table:get patch-legend ptype
        set patch-type ptype
      ]

      if ptype = "dwelling" [
        let i 3
        while [i < array:length data] [
          ask patch x y [
            sprout-dwellings 1 [
              set dwelling-id array:item data i
              set shape "house"
              ;; Give the dwellings a random perturbation so we can see them if
              ;; there are two or more dwellings on a patch. Currently, there will
              ;; not be.
              set xcor x
              set ycor y
            ]
            if i > 3 and pcolor mod 9 > 0 [
              set pcolor pcolor + 1
            ]
          ]
          set i i + 1
        ]
      ]
    ]
    file-close
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; read-insulation-file
;;
;; Read in the set of insulation states available for the run.

to read-insulation-file [filename]
  if filename != false and filename != "null" and length filename > 0 [
    set all-insulation-states []
    foreach (read-csv-with-headings filename) [
      create-insulations 1 [
        set insulation-state table:get ? "insulation-state"
        set all-insulation-states fput insulation-state all-insulation-states
        set fuel-use-factor read-from-string table:get ? "fuel-use-factor"
        set insulation-dwelling-type table:get ? "dwelling-type"
        set hidden? true
      ]
    ]
    set all-insulation-states remove-duplicates all-insulation-states
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; read-insulation-upgrade-file
;;
;; Read in the insulation upgrade file. This lists the upgrade options available
;; for each dwelling type.


to read-insulation-upgrade-file [filename]
  if filename != false and filename != "null" and length filename > 0 [
    foreach (read-csv-with-headings filename) [
      let dw-type table:get ? "dwelling-type"

      let from-state insulations with [insulation-state = (table:get ? "from-state")
        and insulation-dwelling-type = dw-type]
      let to-state insulations with [insulation-state = (table:get ? "to-state")
        and insulation-dwelling-type = dw-type]

      if count from-state != 1 [
        output-print (word "*** Error in insulation file " filename
          ": not 1 insulation for state " (table:get ? "from-state")
          " and dwelling type " dw-type)
      ]

      if count to-state != 1 [
        output-print (word "*** Error in insulation file " filename
          ": not 1 insulation for state " (table:get ? "to-state")
          " and dwelling type " dw-type)
      ]

      ask from-state [
        create-upgrades-to to-state [
          set upgrade-cost read-from-string table:get ? "cost"
          set hidden? true
        ]
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; read-insulation-update-file
;;
;; Read in a list of updates for insulation upgrades, each update (which may add,
;; remove or change an upgrade) being implemented at a specified time-step.

to read-insulation-update-file [filename]
  set insulation-updates []

  if filename != false and filename != "null" and length filename > 0 [
    foreach (read-csv-with-headings filename) [
      set insulation-updates fput ? insulation-updates
    ]
    set insulation-updates reverse insulation-updates
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; read-dwellings-file
;;
;; Read in a dwellings file. The patch-layout file and insulation file should have been
;; read first.

to read-dwellings-file [filename]
  if filename != false and filename != "null" and length filename > 0 [
    foreach (read-csv-with-headings filename) [
      ask dwellings with [dwelling-id = (table:get ? "id")] [
        set dwelling-type table:get ? "type"
        set tenure table:get ? "tenure"
        if table:has-key? ? "shape" [
          set shape table:get ? "shape"
        ]

        let my-insulation-state insulations with [insulation-state = (table:get ? "insulation") and insulation-dwelling-type = [dwelling-type] of myself]
        ifelse count my-insulation-state = 1 [
          create-insulates-from my-insulation-state [
            set hidden? true
          ]
        ]
        [
          output-print (word "*** Error in dwellings file " filename
            ": no insulations with insulation state \"" (table:get ? "insulation") "\" for dwelling type \"" ([dwelling-type] of self) "\"")
        ]
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; read-households-file
;;
;; Read in the households file. The dwellings file should have been read first.

to read-households-file [filename]
  if filename != false and filename != "null" and length filename > 0 [
    foreach (read-csv-with-headings filename) [
      create-households 1 [
        set household-id table:get ? "id"
        set household-type table:get ? "type"
        set steply-net-income read-from-string (table:get ? "income")
        set capital-reserve read-from-string (table:get ? "capital")
        set hedonic read-from-string (table:get ? "hedonic")
        set egoistic read-from-string (table:get ? "egoistic")
        set biospheric read-from-string (table:get ? "biospheric")
        set frame-adjustment read-from-string (table:get ? "frame")
        set planning-horizon read-from-string (table:get ? "planning")
        let dwelling dwellings with [dwelling-id = (table:get ? "dwelling")]
        ifelse count dwelling = 1 [
          create-address-to one-of dwelling [
            set hidden? true
          ]
        ]
        [
          output-print (word "*** Error in household file " filename
            ": Unexpected number of dwellings with id "
            (table:get ? "dwelling") " (expected 1)")
        ]
        set-household-nlogo-params
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; read-social-link-file
;;
;; Read in the social links. This assumes that the household file has already
;; been read.

to read-social-link-file [filename]
  if filename != false and filename != "null" and length filename > 0 [
    file-open filename

    while [not file-at-end?] [
      let line (split "," file-read-line)
      let hh households with [name = first line]
      if count hh > 0 [
        ask hh [
          make-social-links but-first line
        ]
      ]
    ]

    file-close
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; read-social-link-matrix-file
;;
;; Read in the social link matrix file. This contains information on how to
;; create links randomly.

to read-social-link-matrix-file [filename]
  if filename != false and filename != "null" and length filename > 0 [
    set patch-links table:make
    set link-radii-list []
    set radius-links table:make
    set link-patch-types-list []
    set patch-type-links table:make

    let first-row? true

    foreach (read-csv-with-headings filename) [
      if first-row? [
        foreach table:keys ? [
          let parse-heading array:from-list (split " " ?)
          if array:item parse-heading 0 = "radius" [
            set link-radii-list (lput
              read-from-string (array:item parse-heading 1) link-radii-list)
          ]

          if array:item parse-heading 0 = "type" [
            set link-patch-types-list (lput
              (array:item parse-heading 1) link-patch-types-list)
          ]
        ]

        set first-row? false
      ]

      if (not ((table:get ? "A-dwelling") = "*") and (not member? (table:get ? "A-dwelling") dwelling-types-list)) [
        output-print (word "*** Error in social link matrix file " filename ": unrecognised dwelling-type")
      ]
      if (not ((table:get ? "B-dwelling") = "*") and (not member? (table:get ? "B-dwelling") dwelling-types-list)) [
        output-print (word "*** Error in social link matrix file " filename ": unrecognised dwelling-type")
      ]

      if (not ((table:get ? "A-type") = "*") and (not member? (table:get ? "A-type") household-types-list)) [
        output-print (word "*** Error in social link matrix file " filename ": unrecognised household-type")
      ]
      if (not ((table:get ? "B-type") = "*") and (not member? (table:get ? "B-type") household-types-list)) [
        output-print (word "*** Error in social link matrix file " filename ": unrecognised household-type")
      ]

      let A-type (word (table:get ? "A-type") ":" (table:get ? "A-dwelling"))
      let B-type (word (table:get ? "B-type") ":" (table:get ? "B-dwelling"))

      if not table:has-key? patch-links A-type [
        table:put patch-links A-type table:make
        if length link-radii-list > 0 [
          table:put radius-links A-type table:make
        ]
        if length link-patch-types-list > 0 [
          table:put patch-type-links A-type table:make
        ]
      ]

      let A-patch-table table:get patch-links A-type
      let A-radius-table false
      if length link-radii-list > 0 [
        set A-radius-table table:get radius-links A-type
        table:put A-radius-table B-type []
      ]
      let A-type-table false
      if length link-patch-types-list > 0 [
        set A-type-table table:get patch-type-links A-type
        table:put A-type-table B-type []
      ]

      ifelse table:has-key? A-patch-table B-type [
        output-print (word "*** Error in social link matrix file " filename ": parameters linking "
          "household:dwelling " A-type " to " B-type " have already been specified")
      ]
      [
        table:put A-patch-table B-type (table:get ? "p-patch")

        let row ?

        foreach link-radii-list [
          let key (word "radius " ?)
          table:put A-radius-table B-type
            (lput (table:get row key) (table:get A-radius-table B-type))
        ]

        foreach link-patch-types-list [
          let key (word "type " ?)
          table:put A-type-table B-type
            (lput (table:get row key) (table:get A-type-table B-type))
        ]
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; read-external-influences [filename]
;;
;; Read in the times, directions and magnitude of external influences on
;; value-strengths.

to read-external-influences [filename]
  set external-influences-list []
  if filename != false and filename != "null" and length filename > 0 [
    file-open filename
    while [not file-at-end?] [
      let line (split "," file-read-line)
      set external-influences-list lput
        (sentence (read-from-string first line) (item 1 line)
          (item 2 line) (item 3 line) (read-from-string last line))
        external-influences-list
    ]
    file-close
    foreach external-influences-list [
      if (member? (item 2 ?) ["hedonic" "egoistic" "biospheric"] = false) [
        output-print (word "*** Error: unrecognised value " item 2 ?)
      ]
      if (member? (item 3 ?) ["hedonic" "egoistic" "biospheric"] = false) [
        output-print (word "*** Error: unrecognised value " item 3 ?)
      ]
      if (item 2 ? = item 3 ?) [
        output-print (word "*** Error: repeated value" item 2 ?)
      ]
      if ((is-number? last ? = false) or (last ? <= 0)) [
        output-print (word "*** Error: faulty adjustment amount" last ?)
      ]
    ]
  ]
  output-print external-influences-list
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; read-triggers [filename]
;;
;; Read in the events that can trigger goal-frame switching.

to read-triggers [filename]
  set triggers-list []
  if filename != false and filename != "null" and length filename > 0 [
    file-open filename
    while [not file-at-end?] [
      let line (split "," file-read-line)
      set triggers-list lput
        (sentence (read-from-string first line) (read-from-string item 1 line)
          (item 2 line) (item 3 line) (read-from-string last line))
        triggers-list
    ]
    file-close
    foreach triggers-list [
      if (member? (item 2 ?) ["enjoy" "gain" "sustain"] = false) [
        output-print (word "*** Error: unrecognised value " item 2 ?)
      ]
      if (member? (item 3 ?) ["enjoy" "gain" "sustain"] = false) [
        output-print (word "*** Error: unrecognised value " item 3 ?)
      ]
      if (item 2 ? = item 3 ?) [
        output-print (word "*** Error: repeated value" item 2 ?)
      ]
      if ((is-number? last ? = false) or (last ? <= 0) or (last ? > 1)) [
        output-print (word "*** Error: faulty adjustment amount" last ?)
      ]
    ]
  ]
  output-print triggers-list
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; read-appliances [filename]
;;
;; Read in data on the appliances available during the run.

to read-appliances [filename]
  if filename != false and filename != "null" and length filename > 0 [
    foreach (read-csv-with-headings filename) [
      ifelse count appliances with [name = table:get ? "name"] > 0 [
        output-print (word "*** Error: more than one appliance with name \""
          (table:get ? "name") "\" in appliances file " filename)
      ]
      [
        create-appliances 1 [
          set hidden? true
          set name table:get ? "name"
          set category table:get ? "category"
          set subcategory table:get ? "subcategory"
          set essential? read-from-string (table:get ? "essential")
          set hedonic-score read-from-string (table:get ? "hedonic-score")
          set cost-list read-from-string (table:get ? "cost-list")

          let energy-rating-str (table:get ? "energy-rating")
          ifelse energy-rating-str = "NA" [
            set energy-rating-provided? false
          ]
          [
            set energy-rating-provided? true
            set energy-rating read-from-string energy-rating-str
          ]

          set embodied-energy read-from-string (table:get ? "embodied-energy")
          set breakdown-probability read-from-string
          (table:get ? "breakdown-probability")
          set first-step-available read-from-string
          (table:get ? "first-step-available")

          let last-step-available-str (table:get ? "last-step-available")

          ifelse last-step-available-str = "Inf" [
            set last-step-available-unbounded? true
          ]
          [
            set last-step-available-unbounded? false
            set last-step-available read-from-string last-step-available-str
          ]
        ]
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; read-replacements [filename]
;;
;; Read the equipment replacements from the file. This is a CSV file without
;; headings in which the first column is the name of an appliance, and the
;; remaining columns for that row are the names of all the appliances that can
;; replace that appliance. The replacements file must be read after the
;; appliances file.

to read-replacements [filename]
  if filename != false and filename != "null" and length filename > 0 [
    file-open filename
    while [not file-at-end?] [
      let line split "," file-read-line
      ask appliances with [name = first line] [
        foreach but-first line [
          let other-appliance one-of appliances with [name = ?]
          if other-appliance != self [
          ;; Since a check is always made that a possible replacement is available
          ;; at the current step, it does not matter for the functioning of the
          ;; program if an item recorded as a possible replacement is not available
          ;; any time the item might need replacing; while if self is found in the
          ;; list of replacements, it is to be ignored.
            create-replacement-to other-appliance [
              set hidden? true
            ]
          ]
        ]
      ]
    ]
    file-close
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; read-fuel [filename]
;;
;; Read fuel types from the file. This is a CSV file with three heading columns:
;; type, unit and kWh. One fuel agent will be created for each row. Each entry in
;; the type column must be unique.

to read-fuel [filename]
  if filename != false and filename != "null" and length filename > 0 [
    foreach (read-csv-with-headings filename) [
      ifelse count fuels with [fuel-type = (table:get ? "type")] > 0 [
        output-print (word "*** Error in fuel file " filename
          ": More than one fuel with type \"" (table:get ? "type") "\"")
      ]
      [
        create-fuels 1 [
          set hidden? true
          set fuel-type table:get ? "type"
          set unit table:get ? "unit"
          set kWh-per-unit read-from-string (table:get ? "kWh")
          set fuel-plot-colour ifelse-value table:has-key? ? "colour" [
            table:get ? "colour"
          ]
          [
            black
          ]
        ]
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; read-energy-prices [filename]
;;
;; Read in the list of energy prices for each fuel type. This will produce a
;; list of fuel-type to price tables: the energy-price-list.

to read-energy-prices [filename]
  set energy-price-list []
  if filename != false and filename != "null" and length filename > 0 [
    file-open filename
    if file-at-end? [
      output-print (word "*** Error: Suppliers file " filename " is empty!")
    ]

    let fuels-list split "," file-read-line

    ;; Before reading in the data, check the fuels have been defined.
    foreach fuels-list [
      if count fuels with [fuel-type = ?] = 0 [
        output-print (word "*** Error: No fuel defined with type \"" ? "\"")
      ]
    ]

    ;; Now read in the data
    let fuels-arr array:from-list fuels-list
    while [ not file-at-end? ] [
      let pricestring split "," file-read-line
      let timestep-prices table:make
      (foreach fuels-list pricestring [
        table:put timestep-prices ?1 read-from-string ?2
      ])
      set energy-price-list lput timestep-prices energy-price-list
    ]

    file-close
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; read-appliances-fuel-use [filename]
;;
;; Read the fuel use of each appliance. This populates the consumes links. The
;; file format is CSV, where each row corresponds to a usage of an appliance in
;; a particular context. The fuel file must have been read first. The CSV file
;; must have a headings row with at least the following headings: appliance,
;; fuel, household, dwelling, purpose, step, units.

to read-appliances-fuel-use [filename]
  if filename != false and filename != "null" and length filename > 0 [
    foreach (read-csv-with-headings filename) [
      let this-appliance appliances with [name = table:get ? "appliance"]

      if count this-appliance = 0 [
        output-print (word "*** Error reading appliances fuel file \"" filename
          "\": no appliances with name \"" (table:get ? "appliance") "\"")
      ]
      if count this-appliance > 1 [
        output-print (word "*** Error reading appliances fuel file \"" filename
          "\": there are two or more appliances with name \""
          (table:get ? "appliance") "\"")
      ]

      ;; A wild card cannot be used here for household types
      ;; because household-types-list is defined in setup-households,
      ;; which is read after setup-appliances.
      let hhtlist (list (table:get ? "household"))
      let dwtlist ifelse-value (table:get ? "dwelling" = "*")
        [dwelling-types-list] [ (list (table:get ? "dwelling")) ]
      let ttlist ifelse-value (table:get ? "tenure" = "*")
        [tenure-types-list] [ (list (table:get ? "tenure")) ]
      let uselist ifelse-value (table:get ? "mode" = "*")
        [usage-modes-list] [ (list (table:get ? "mode")) ]
      let line-table ?

      ;; Now do a foreach loop through all the nested loops.
      foreach hhtlist [
        let hht ?

        foreach dwtlist [
          let dwt ?

          foreach ttlist [
            let tt ?

            foreach uselist [
              let use ?

              foreach steps-list [
                let stp ?

                let the-fuel fuels with [fuel-type = table:get line-table "fuel"]

                if count the-fuel = 0 [
                  output-print (word "*** Error reading appliances fuel file \""
                    filename "\": There are no fuels with type \""
                    table:get line-table "fuel" "\"")
                ]
                if count the-fuel > 1 [
                  output-print (word "*** Error reading appliances fuel file \""
                    filename "\": There are two or more fuels with type \""
                    table:get line-table "fuel" "\"")
                ]

                create-consumption-patterns 1 [
                  set hidden? true
                  set for-household-type hht
                  set for-dwelling-type dwt
                  set for-tenure-type tt
                  set for-purpose table:get line-table "purpose"
                  set in-usage-mode use
                  set in-step stp

                  create-use-to one-of the-fuel [
                    set hidden? true

                    if not table:has-key? line-table (word "units " stp) [
                      output-print (word "*** Error reading appliances fuel file \""
                        filename "\": No column data for step " stp
                        ". Check steps-per-year -- currently " steps-per-year)
                    ]
                    set units-per-use read-from-string table:get line-table (word "units " stp)
                  ]
                  create-consume-from one-of this-appliance [
                    set hidden? true
                  ]
                ]
              ]
            ]
          ]
        ]
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; read-initial-appliances-file [filename]
;;
;; Read the household initial appliances file.

to read-initial-appliances-file [filename]
  if filename != false and filename != "null" and length filename > 0 [
    set initial-hh-appliances table:make
    set initial-hh-address-appliances table:make
    set initial-hh-dw-type-appliances table:make

    file-open filename
    while [not file-at-end?] [
      let data (split-no-null "," file-read-line)

      let hh-dw-id (split-no-null ":" (first data))
      ifelse length hh-dw-id = 1 [
        ;; It's a household name -- add it to initial-hh-appliances.

        table:put initial-hh-appliances (first data) (but-first data)
      ]
      [
        ifelse length hh-dw-id = 2 [
          ;; It's a household-type:dwelling-name -- add it to initial-hh-address-appliances

          table:put initial-hh-address-appliances (first data) (but-first data)
        ]
        [
          ifelse length hh-dw-id = 3 [
            ;; it's a household-type:tenure:dwelling-type -- add it to initial-hh-dw-type-appliances

            table:put initial-hh-dw-type-appliances (first data) (but-first data)
          ]
          [
            output-print (word "*** Warning: invalid household/dwelling identifier \""
              (first data) "\" in household-init-appliance-file " filename " -- "
              "ignoring this line")
          ]
        ]
      ]
    ]
    file-close
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; read-table2
;;
;; Creates a two-level table from a file in which each line encodes a table as
;; alternating keys and values. The first item in a line is a key for the main
;; table, the remaining items are alternating keys and values for a subtable.

to-report read-table2 [table-file]
  let table table:make
  file-open table-file
  while [not file-at-end?] [
    let line file-read-line
    let data (split "," line)
    let key (first data)
    let value (list-to-table but-first data)
    table:put table key value
  ]
  report table
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                                            ;;
;; Utilities                                                                  ;;
;;                                                                            ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; make-social-links [other-hh]
;;
;; Make social links from a household to all the households in the list.

to make-social-links [other-hh]
  while [length other-hh > 0] [
    if not name = first other-hh [
      let hh one-of households with [name = first other-hh]
      if not hh = nobody and not social-link-neighbor? hh [
        create-social-link-with hh
        set other-hh but-first other-hh
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; my-member?
;;
;; Return whether or not an item is a member of a collection, allowing for
;; the possibility that either the item or the collection may be nobody.

to-report my-member? [an-item a-collection]
  report ifelse-value (an-item = nobody) [
    false
  ]
  [
    ifelse-value (a-collection = nobody) [
      false
    ]
    [
      member? an-item a-collection
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; split
;;
;; Separate some text into a list of strings delimited by the separator.

to-report split [separator text]
  let cells []
  let mytext text
  while [position separator mytext != false] [
    set cells fput (substring mytext 0 (position separator mytext)) cells
    set mytext substring mytext ((position separator mytext)
      + length separator) length mytext
  ]
  set cells fput mytext cells
  report reverse cells
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; split-no-null
;;
;; Split and remove null entries.

to-report split-no-null [separator text]
  let cells split separator text
  let no-nulls []

  foreach cells [
    if length ? > 0 [
      set no-nulls fput ? no-nulls
    ]
  ]

  report reverse no-nulls
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; list-to-table
;;
;; Returns a table made by interpreting a list as alternating keys and values

to-report list-to-table [list1]
  let table table:make
  while [length list1 > 0] [
    table:put table (first list1) read-from-string (first but-first list1)
    set list1 but-first (but-first list1)
  ]
  report table
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; show-licence-message
;;
;; Show the GNU GPL message when the model runs.

to show-licence-message
  print "CEDSS 3.4  Copyright (C) 2016"
  print "Nick Gotts, Gary Polhill and The James Hutton Institute"
  print "This program comes with ABSOLUTELY NO WARRANTY. This is free software,"
  print "and you are welcome to redistribute it under certain conditions; for"
  print "more information on this, and the (lack of) warranty, see the LICENCE"
  print "section in the Information tab."
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; my-export-all-plots
;;
;; Export all plots to a file that is guaranteed not to exist.

to my-export-all-plots [filename]
  ifelse file-exists? filename [
    let stem substring filename 0 (length filename - 4)
    let x 0
    set filename (word stem "-" x ".csv")

    while [file-exists? filename] [
      set x x + 1
      set filename (word stem "-" x ".csv")
    ]
    export-all-plots filename
  ]
  [
    export-all-plots filename
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                                            ;;
;; Condition rules for the usage matrix                                       ;;
;;                                                                            ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; negative-capital-reserve
;;
;; Not in current use.

to-report negative-capital-reserve
  ifelse capital-reserve < 0 [
    report true
  ]
  [
    report false
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
223
511
889
1024
-1
-1
19.3
1
10
1
1
1
0
0
0
1
0
33
0
24
0
0
1
ticks
30.0

BUTTON
28
436
92
470
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
112
436
176
470
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
113
479
176
512
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
5
572
205
722
Total energy use
Step
Energy use
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

PLOT
5
724
205
874
Total capital reserves
Step
Capital reserves
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

SLIDER
547
14
719
47
halt-after
halt-after
0
480
200
1
1
NIL
HORIZONTAL

SLIDER
4
527
200
560
max-energy-display
max-energy-display
0
10000
1000
250
1
kWh
HORIZONTAL

PLOT
5
876
205
1026
Number of links
Step
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

SLIDER
207
143
443
176
max-links
max-links
0
50
8
1
1
NIL
HORIZONTAL

SLIDER
690
104
923
137
credit-multiple-limit
credit-multiple-limit
-50
100
-15
1
1
NIL
HORIZONTAL

SWITCH
389
66
564
99
reciprocal-adjustment
reciprocal-adjustment
0
1
-1000

INPUTBOX
449
374
685
434
patch-file
cedss3.3-patch-Urban1-20120324.csv
1
0
String

INPUTBOX
207
247
443
307
energy-prices-file
cedss3.4-energy-prices-S-stable-20141216.csv
1
0
String

INPUTBOX
207
184
443
244
appliances-file
cedss3.4-appliances-S-regmidimp-20150203.csv
1
0
String

INPUTBOX
209
437
444
497
social-link-matrix-file
cedss3.3-slm-20120325full.csv
1
0
String

BUTTON
26
478
92
513
NIL
profile
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
599
66
716
99
user-files
user-files
1
1
-1000

INPUTBOX
691
375
926
435
patch-legend-file
cedss3.3-block-square-legend-20120324.csv
1
0
String

INPUTBOX
932
183
1167
243
dwellings-file
cedss3.3-dwellings-Urban-20140221.csv
1
0
String

INPUTBOX
691
438
926
498
usage-mode-matrix-file
unchanging-usage-20141104.csv
1
0
String

INPUTBOX
933
247
1168
307
household-file
cedss3.4-households-Urban-20141129-plan8.csv
1
0
String

INPUTBOX
934
375
1169
435
social-link-file
null
1
0
String

SWITCH
988
64
1163
97
use-social-link-file
use-social-link-file
1
1
-1000

INPUTBOX
690
184
925
244
appliances-replacement-file
cedss3.4-replacements-S-regfastimp-20150203.csv
1
0
String

INPUTBOX
690
247
925
307
fuel-file
cedss3.3-fuel-20120317.csv
1
0
String

INPUTBOX
449
184
684
244
appliances-fuel-file
cedss3.4-appliances-fuel-S-regfastimp-20150204.csv
1
0
String

TEXTBOX
917
21
1067
39
<< Parameters
11
0.0
1

TEXTBOX
57
171
207
189
Input files >>
11
0.0
1

TEXTBOX
719
66
801
94
Browse for all input files
11
0.0
1

TEXTBOX
1012
10
1199
53
CEDSS 3.4
32
12.0
1

OUTPUT
0
26
203
419
13

TEXTBOX
55
10
146
28
Errors/Warnings
11
0.0
1

SWITCH
806
64
983
97
use-household-file
use-household-file
0
1
-1000

PLOT
5
1030
205
1205
Appliances
Step
Appliances
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

SLIDER
690
142
923
175
new-subcategory-steps
new-subcategory-steps
0
100
8
1
1
NIL
HORIZONTAL

SLIDER
931
142
1165
175
visits-per-step
visits-per-step
0
40
1
1
1
NIL
HORIZONTAL

PLOT
952
570
1152
720
Land fill
subcategory
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

PLOT
952
723
1152
874
Goal frame
Step
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"enjoy" 1.0 0 -2674135 true "" ""
"gain" 1.0 0 -13345367 true "" ""
"sustain" 1.0 0 -10899396 true "" ""

PLOT
952
880
1152
1027
Goal frame parameters
Step
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"hedonic" 1.0 0 -2674135 true "" ""
"egoistic" 1.0 0 -13345367 true "" ""
"biospheric" 1.0 0 -10899396 true "" ""

PLOT
953
1030
1153
1180
Visits per link
Step
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"mean" 1.0 0 -16777216 true "" ""
"min" 1.0 0 -13345367 true "" ""
"max" 1.0 0 -2674135 true "" ""

CHOOSER
207
14
345
59
steps-per-year
steps-per-year
4 12 26 52 365
0

TEXTBOX
350
15
500
57
N.B. No adjustment is made to input data using the steps-per-year parameter
11
0.0
1

INPUTBOX
450
311
685
371
insulation-file
cedss3.3-insulation20140221.csv
1
0
String

INPUTBOX
690
311
925
371
insulation-upgrade-file
cedss3.3-insulation-upgrade-20140221.csv
1
0
String

INPUTBOX
933
311
1168
371
insulation-update-file
null
1
0
String

INPUTBOX
209
373
443
433
maximum-in-category-file
cedss3.3-maximum-in-category-20141207.csv
1
0
String

SLIDER
448
142
684
175
new-subcategory-appliances-per-step
new-subcategory-appliances-per-step
0
10
0
1
1
NIL
HORIZONTAL

INPUTBOX
208
310
443
370
household-init-appliance-file
cedss3.4-initial-appliances-Urban-20150201.csv
1
0
String

SLIDER
930
103
1164
136
habit-adjustment-factor
habit-adjustment-factor
0
10
0.2
0.1
1
NIL
HORIZONTAL

SWITCH
207
66
384
99
fill-empty-properties
fill-empty-properties
1
1
-1000

PLOT
317
1033
517
1175
Appliance subcategories
Step
Appliances
0.0
10.0
0.0
10.0
true
false
"" ""
PENS

PLOT
580
1032
780
1173
Insulation states
Step
States
0.0
10.0
0.0
10.0
true
false
"" ""
PENS

INPUTBOX
449
247
684
307
external-influences-file
null
1
0
String

SLIDER
449
104
684
137
biospheric-boost-factor
biospheric-boost-factor
0
100
0
1
1
NIL
HORIZONTAL

SLIDER
207
104
443
137
biospheric-boost-ceiling
biospheric-boost-ceiling
0
10000
1000
10
1
NIL
HORIZONTAL

INPUTBOX
449
438
685
498
triggers-file
null
1
0
String

@#$#@#$#@
## WHAT IS IT?

This is CEDSS 3.4 (Community Energy Demand Social Simulator) (Polhill and Gotts 2015, Gotts and Polhill forthcoming). It is based on CEDSS 3.3 (Gotts et.al. 2014), from CEDSS 3.2, from CEDSS 3.1, from CEDSS 3.0, which was built from CEDSS 2.0. CEDSS 2.0 was built from ABMED-1.2, itself derived from ABMED (Agent-Based Model of Energy Demand) as presented to ESSA at the University of Surrey (Gotts 2009). ABMED, and CEDSS up to version 3.3, were developed as part of the GILDED (Governance, Infrastructure, Lifestyle Dynamics and Energy Demand) EU Framework Programme 7 project, Grant number 228353, funded under theme SSH-2007-2.1-04 SSH-2007-2.1-04 "Socio-Economic Factors and Actors that Shape the 'Post-Carbon' Society". Some information about GILDED is available at http://gildedeu.hutton.ac.uk/, although the site is no longer maintained. CEDSS 3.3 (Gotts et. al. 2014, Gotts and Polhill 2014) was the first published version of the model, and is available at https://www.openabm.org/model/3642/version/2/view. CEDSS 3.4 corrects errors found in CEDSS 3.3, and adds functionality to simulate further features of goal-framing theory (Lindenberg and Steg 2007, Steg et.al. 2014), and the effect of influences from government or NGO information campaigns, and public opinion. Some untested and obsolete code has also been removed.

## HOW IT WORKS

The CEDSS world consists of patches, dwellings, households, appliances, consumption-patterns and fuels.

Patches represent a unit area of space, and have a type, which is a string label. Patches with type "dwelling" may have one or more dwellings on them (but the facility for multiple dwellings on a patch has not yet been used), and are used to determine social link configuration (see file 5: social link matrix file).

Dwellings have a type, which together with the household type and a number of other factors, determine usage of appliances. Dwellings also have an insulation state. Multiple kinds of insulation are possible, and each insulation state (combination of kinds of insulation) has an insulation factor that determines the fuel use of space-heating appliances.

Households are the decision-making agents in the model (other CEDSS entities referred to as "agents" in NetLogo terminology are really just objects). They live in a dwelling, and own appliances. The decision-making they do pertains entirely to the purchase of appliances, except that there is provision, so far unused, for decisions between different "usage-modes", in which households would use appliances more or less intensively. The way that households make their purchase decisions is based on the theory of "goal frames" (Lindenberg and Steg 2007), in which choices can be made in one of three modes: "hedonistic", "gain" and "norm". We have chosen to hyphenate the term to indicate that CEDSS "goal-frames" are based on but not identical to the theoretical constructs of goal frame theory; other variations on the theory's terminology are similarly motivated. The current relative magnitudes of three household "value-strength" parameters ("hedonic", "egoistic" and "biospheric") determine the probability that the corresponding goal-frame ("enjoy", "gain" or "sustain" respectively) will be selected in each time-step. The "enjoy" goal-frame encourages the purchase of more non-essential appliances than the other two; "gain" choices are based on minimising costs, and "sustain" choices on minimising energy demand.

Households have (bidirectional) social links with each other, and linked households may "visit" each other. When a household visits another household, their value-strength parameters may be adjusted to be closer to each other (they could in principle move away from each other instead). If a household in the enjoy goal-frame visits another household, then some of the latter's Appliances will be added to the former's "wish-list" of appliances to buy.

Households have a usage-mode, which indicates the manner in which they use all their appliances. As far as CEDSS 3.4 is concerned, this usage-mode is an abstract concept, simply a label for consumption-patterns to apply when determining energy consumption; and as yet, only one usage-mode ("normal") has been implemented.

Household type represents a demographic state of the household, and creates the possibility, as yet unused, for households of different types to have different consumption-patterns. The consumption-pattern NetLogo "agents" lie on a link between appliances and fuels. Each appliance has one or more consumption-patterns, each of which in turn uses one or more types of fuel. Consumption-patterns are labelled by purpose, household type, dwelling type, usage-mode, and month of the year. (See appliances-fuel-use file below.)

Appliances have a cost, an energy-rating, and a hedonic-score (the last unused at present), which can be used to determine their selection in various goal frames. Technical innovation in appliances can be created as a driving variable of the model using the first-month-available and last-month-available properties of appliances, which have the meaning you should expect from their names. (The time-step in the model is set by the steps-per-year parameter, but is generally a quarter-year.) Appliances can be potential replacements for other appliances.

Appliances have a breakdown-probability, which influences when they break down and need replacing. Appliances may be essential, in which case they are always replaced, regardless of the household's financial situation.

Each time-step in a model run, the following takes place (note that it has several capabilities that have not yet been employed in model runs).[Square brackets identify the relevant procedure(s).]:


1.	New appliances and ways of upgrading insulation may enter the market, existing ones may become unavailable [go, update-insulation-upgrades].
2.	Decide stochastically which appliances break down [calculate-breakdowns].
3.	Each household then does the following [step] (the order of the phases can vary with the goal-frame):
a.	Determine its goal-frame, and adjust its value strengths accordingly to reflect the influence of habit [choose-goal-frame].
b.	Consider over-riding the goal-frame selected at a, if contextual “triggers” are present [adjust-goal-frame].
c.	Choose its usage-mode [get-usage-mode]. (Currently trivial, as only one mode is available.)
d.	Compute its energy use for this step from using appliances and space/water heating. Amounts for each combination of fuel (electricity, gas, oil) and type of consumption - space-heating, water-heating, (non-heating) appliances - are added to totals for all households [calculate-moeu].
e.	Compute its financial situation [calculate-finance].
f.	Replace broken appliances [replace-broken-appliances].
g.	Visit social neighbours [visit]. (This follows step l if goal-frame is not ‘enjoy’.)
h.	Update its wish list (if goal-frame is ‘enjoy’ only) [update-wish-list].
i.	Buy insulation (if goal-frame is not ‘enjoy’) [buy-insulation].
j.	Buy non-essential appliances [enjoy-equip-nonessential, gain-equip-nonessential, sustain-equip-nonessential].
k.	Update social links [update-links].
l.	Absorb external influences [absorb-external-influences].
m.	Calculate its new liquid capital reserve, add it to the all-households total.
n.	Add its energy use for the time-step to the all-households total.
4.	Display and record information.
a.	Show changes on the user interface, if that is employed [show-changes].
b.	Update plots recording the run [my-update-plots].
c.	Amounts of each type of energy used for non-heating appliances [calculate-appliance-energy-use] and for heating [calculate-heating-energy-use] are calculated and printed [output-print].

To initialise the model, CEDSS loads in the input files (see below: HOW TO USE IT), and creates households, appliances, fuels, dwellings, patches and consumption-patterns from the data therein. As part of the initialisation process, households make random social links with each other (even if specific social links have been requested). The probability of forming social links randomly is determined by the social link matrix file (file 5). See below for more information.

Some of the data in the files is time-series data. In particular, the appliance file contains information on which appliances are available over what time periods. The household transition matrix file may be used to adjust household demographic parameters over the course of a simulation, if required. Time series information on energy prices is contained in the energy proce file (file 10).

## HOW TO USE IT

CEDSS 3.4 is configured using a number of files, which the user creates or copies. All files have a CSV format. Some of the examples given are actual complete or partial files that have been used with the model - these are indicated by the notation "Actual example file". Three dots: "..." in these cases mean part of the file has been omitted. Others are hypothetical example files; these are used where some feature of the model cannot be illustrated from files actually used. Here, <etc.> may be used to indicate that the actual file would be considerably longer than the example.

(1) The patch legend file simply provides colours for each type of patch, simultaneously specifying the patch types the simulation will be working with. Its format is CSV, in two columns (other columns are ignored) the first is the name of the patch type, the second is the NetLogo color that will be used to represent that patch type in the space (a NetLogo color may be represented either by a string or an integer). Actual example file:

    dwelling	green
    street	gray
    park	52
    junction	6

(2) The patch file states the patch type of a patch. Like the patch legend file, it has no header row; data are given in order X, Y, patch-type, dwelling-id..., where X and Y are coordinates, dwelling-id is a comma-separated list of dwellings on that patch, and is only used if patch-type is "dwelling". Patch-type should correspond to one of the types in the patch legend file. Hypothetical example file:

    0,0,street
    0,1,street
    0,2,dwelling,house-1
    0,3,street
    0,4,dwelling,flat-1,flat-2,flat-3,flat-4,flat-5,flat-6
    <etc.>

(3) The dwellings file gives properties of each dwelling. This should have a heading row, with the following headings specified in any order: "id", "tenure", "type", "insulation". (Optionally, the "shape" column may be given. Entries in this column should be a valid NetLogo shape, which will be used to set the shape of the dwelling -- e.g. to allow different types of dwelling to be distinguished visually. Shapes imported from the shapes library include "house", "house bungalow", "house colonial", "house efficiency", "house ranch", "house two story") There is then one row for each dwelling, where the entry in the "id" column corresponds to the dwelling-id in the patch file. The set of tenure types will be inferred from this file, and is expected to be consistent with all other files where tenure is mentioned. Entries in the "type" column should correspond to entries in the "dwelling" column of the appliances fuel file; they are used to calculate space-heating energy use. Entries in the insulation column should correspond to entries in the insulation file, used for the same purpose. Actual example file:

    id		tenure	type			insulation
    dwu-29	owned	house-semi-solid-3	minimum
    dwu-42	owned	flat-non-top-solid-1	dg-loft100
    dwu-46	owned	flat-top-solid-1	dg-loft100
    dwu-51	owned	flat-non-top-cavity-2	loft100
    dwu-93	owned	house-end-solid-3	dg
    dwu-98	owned	flat-non-top-cavity-1	loft100
    dwu-104	rented	flat-non-top-cavity-2	dg-loft100
    dwu-107	owned	bung-det-solid-4	loft100
    dwu-115	rented	flat-non-top-cavity-2	dg-loft100
    dwu-230	rented	flat-non-top-cavity-1	loft100-cwi
    dwu-236	owned	house-semi-solid-3	dg-loft100
    ...

Top storey and non-top storey flats are distinguished, the latter being assigned a default 100mm of loft insulation to reflect the insulation they receive from flats above them. The term "dg" stands for double-glazing, "cwi" for cavity-wall insulation and swi (not shown in the example) for solid-wall insulation.

(4) The household file allocates initial households and their parameters to each dwelling. It has a heading row indicating the columns, which may be in any order. The following columns are required: id, type, income, capital, hedonic, egoistic, biospheric, frame, planning. Of these, capital, hedonic, egoistic, biospheric, frame, and planning are expected to be numeric; income is expected to be a list of numerics (indicating income available for spending on energy and energy-related equipment in successive time-steps) and type is the type of household, referenced by a number of procedures (in experiments up to now, there has been only one type). Actual example file:

    hhu-29	household	dwu-29	[322 322 322 322 295 295 295 295 295 295 295 295  	312 312 312 312 280 280 280 280 296 296 296 296 322 322 322 322 341 341 341 341   	350 350 350 350 429 429 429 429 429 429]	341	1.714560112	                  3.790019416	0.884983635	0.2	20
    hhu-42	household	dwu-42	[363 363 363 363 332 332 332 332 332 332 332 332  	302 302 302 302 359 359 359 359 360 360 360 360 341 341 341 341 428 428 428 428 		439 439 439 439 441 441 441 441 441 441]	8925	3.968977439				4.732196171	0.264718996	0.2	20
    hhu-46	household	dwu-46	[212 212 212 212 212 212 212 212 212 212 212 212 		202 202 202 202 233 233 233 233 211 211 211 211 230 230 230 230 251 251 251 251 		256 256 256 256 313 313 313 313 313 313]	1	4.588994936				0.184920598	0.03211146	0.2	20
    hhu-51	household	dwu-51	[322 322 322 322 295 295 295 295 295 295 295 295 		312 312 312 312 280 280 280 280 296 296 296 296 322 322 322 322 341 341 341 341 		350 350 350 350 429 429 429 429 429 429]	341	3.051400624				2.46654544	0.925957717	0.2	20
    hhu-93	household	dwu-93	[407 407 407 407 321 321 321 321 321 321 321 321 		347 347 347 347 456 456 456 456 365 365 365 365 441 441 441 441 429 429 429 429 		402 402 402 402 475 475 475 475 475 475]	620	1.752844503				2.469098331	0.152570834	0.2	20
    hhu-98	household	dwu-98	[233 233 233 233 237 237 237 237 237 237 237 237 		248 248 248 248 252 252 252 252 330 330 330 330 304 304 304 304 311 311 311 311 		346 346 346 346 365 365 365 365 365 365]	5000	1.139610055				1.864347715	0.963611213	0.2	20
    ...

(5) The social link matrix file specifies, for each pair of household/dwelling type combinations, the probability of making links between agents belonging to these types under various circumstances. Tenure is ignored. These circumstances are:
a) Between households in dwellings on the same patch  .
b) Between households in dwellings on neighbouring patches within a specified distance.
c) Between households in dwellings separated by one or more contiguous patches of a given type. If the type is "dwelling" then it is all patches of type "dwelling" where there exists a path from the household's dwelling's patch to the other patch crossing only "dwelling" patch types. For all other types, there must exist a path from a neighbour of the dwelling's patch with the specified type to a neighbour of the linked dwelling's patch also with the specified type crossing only the specified type of patches.

There can be as many (0 or more) (b) and (c) links as desired, determined by column headings. Each probability is treated independently. Hence if there are two type (b) links, one with radius x, probability p1, another with radius y, probability p2, where y > x, then the probability of making a link within radius x is p1 + (1 - p1)p2; that of making a link within the doughnut from x to y is p2.

Hypothetical example file:

    A-type,A-dwelling,B-type,B-dwelling,p-patch,radius 5,radius 10,type street
    DINK,house,DINK,house,0.5,0.2,0.05,0.1
    DINK,house,DINK,flat,0.5,0.2,0.05,0.1
    DINK,house,KIPPERS,house,0.2,0.05,0.01,0.1

(6) [Optional] The social link file allows the user to specify a particular initial social link topology for each household. Its format puts the name of a household in the first column, and the names of all the other households they are linked to in subsequent columns (there is no need to assume that all households must have the same number of links). Social links are undirected, so there is only any need to specify a particular link once. Hypothetical example file:

    smith,hhu-29,kovacs
    hhu-29,kovacs
    hhu-45,hhu-29,kovacs
    jones,hhu-29,hhu-42,kovacs

(7) The usage mode matrix file specifies the conditions under which each goal frame has a particular usage-mode. A usage-mode defines appliance usage profiles, which are specified for each household and dwelling type in the appliances fuel file (11). These conditions are tags for rules in the CEDSS model. These rules are specified by reporters returning a boolean value (at the bottom of the code in the Procedures tab). If you want to create other rules, you will need to add a procedure to the model, and edit the get-usage-mode procedure to add the tag for your usage-mode. You should also add some documentation here. Hypothetical example file:

    goal-frame,normal,economising
    hedonic,true,false
    egoistic,not negative-capital-reserve,negative-capital-reserve
    biospheric,not negative-capital-reserve,negative-capital-reserve

Note the use of "not" to negate a condition, and "true" and "false" to say the usage-mode always or never applies to the goal-frame, respectively.

Conditions currently recognised by CEDSS are:

* negative-capital-reserve: capital-reserve < 0

(8) The appliances file gives properties of each appliance. The file includes a header row, and each subsequent row gives the required details for each appliance. Columns can be in any order. The name is a unique name for the appliance. Category and subcategory are used in determining what can be bought under various circumstances. "Essential" means, "households will replace it immediately because they can't live without it" and is either true or false. Hedonic score is for use in the enjoy goal frame, but has not in fact been used. Cost is a list of purchase prices covering the time-steps during which the appliance is available (if the list is exhausted while the appliance is still available, the last price is used), energy-rating is information about the energy consumption of the appliance given to consumers, with a lower score meaning better energy consumption. (The actual energy consumed by appliances for different purposes is given in the appliances fuel file (11).) The breakdown-probability is the probability, per time-step, of the equipment breaking down. The first and last steps available are the numbers of the time-steps in the model indicating when they are first and last available. 'Inf' is used for the last-step-available if the appliance is always available after its first appearance. Actual example file:

name	category	subcategory	essential	hedonic-score	cost-list		energy-rating	embodied-energy	breakdown-probability	first-step-available			last-step-available
    oil-condensing-boiler-A	heating	oil-conboiler-sub	TRUE	0	[2500]	3		0	0.013	0	59
	oil-condensing-boiler-A2	heating	oil-conboiler-sub	TRUE	0			[2500]	3	0	0.013	60	Inf
    electric-heaters	heating	electric-heating	TRUE	0	[2000]	0	0		0.013	0	Inf
    ...
    Teba TFR14	cooker	electric-cooker-sub	TRUE	0	[200]	11	0			0.014	0	3
    Creda Capri C150E	cooker	electric-cooker-sub	TRUE	0	[250 250 250 250 		230 230]	11	0	0.014	0	5
    Beko DV 5631	cooker	electric-cooker-sub	TRUE	0	[400 400 400 400 		380 380 380 380 380 380 380 380]	11	0	0.014	0	11
    ...


(9) The appliance replacement file gives replacements for each appliance. Each row lists the names of the appliances that can, when available for purchase, replace the appliance in the first column. Names of appliances should correspond to names of appliances in the appliances file (8). An appliance should not be listed as a replacement for itself. Actual example file:

    oil-condensing-boiler-A									    electric-heaters									      ...
    Teba TFR14	Teba TFR14	Creda Capri C150E	Beko DV 5631	Tricity Bendix 			SIE 324	Jackson by Creda J15 1EW	Belling Forum 335	Zanussi ZCE611X			Zanussi ZCE531X	Zanussi ZCE641	New World 50WLG	Belling Forum 317	Beko D532		Hotpoint HL500 electric	Indesit KD3E1	Hotpoint HW170E	Creda Menu M350E			Tricity Bendix SIE 514	Beko DVC61	Creda X155	Tricity Bendix SIE 554			Tricity Bendix SE340	Belling 644	Beko DCC 4521	Leisure Roma 50	Beko 			DC543	Leisure Zenith ZE6HV	Beko DVC563	Indesit K6 C320	Hotpoint EW74			Hotpoint Creda C367
    Creda Capri C150E	Teba TFR14	Creda Capri C150E	Beko DV 5631	Tricity 		Bendix SIE 324	Jackson by Creda J15 1EW	Belling Forum 335	Zanussi 		ZCE611X	Zanussi ZCE531X	Zanussi ZCE641	New World 50WLG	Belling Forum 317			Beko D532	Hotpoint HL500 electric	Indesit KD3E1	Hotpoint HW170E	Creda 			Menu M350E	Tricity Bendix SIE 514	Beko DVC61	Creda X155	Tricity 		Bendix SIE 554	Tricity Bendix SE340	Belling 644	Beko DCC 4521	Leisure 		Roma 50	Beko DC543	Leisure Zenith ZE6HV	Beko DVC563	Indesit K6 C320			Hotpoint EW74	Hotpoint Creda C367
    Beko DV 5631	Teba TFR14	Creda Capri C150E	Beko DV 5631	Tricity 		Bendix SIE 324	Jackson by Creda J15 1EW	Belling Forum 335	Zanussi 		ZCE611X	Zanussi ZCE531X	Zanussi ZCE641	New World 50WLG	Belling Forum 317			Beko D532	Hotpoint HL500 electric	Indesit KD3E1	Hotpoint HW170E	Creda 			Menu M350E	Tricity Bendix SIE 514	Beko DVC61	Creda X155	Tricity 		Bendix SIE 554	Tricity Bendix SE340	Belling 644	Beko DCC 4521	Leisure 		Roma 50	Beko DC543	Leisure Zenith ZE6HV	Beko DVC563	Indesit K6 C320			Hotpoint EW74	Hotpoint Creda C367
    ...

(10) The fuel file gives properties of each fuel used to supply an appliance. Most appliances will only use one type of fuel, but some (e.g. a cooker) might use two (e.g. gas and electricity), or possibly more. This is a simple three-column file with columns type, unit and kWh. The latter column gives the number of kWh of energy per unit of consumption of the fuel. It has in fact turned out to be most convenient to distinguish between different uses of a fuel (for space-heating, water-heating and non-heating appliances) as if they were different fuels, and to use kWh for the unit of consumption in all cases. Actual example file:

    type		unit		kWh
    space-heating-elect	sh-elect-kWh	1
    water-heating-elect	wh-elect-kWh	1
    appliance-elect	ap-elect-kWh	1
    space-heating-gas	sh-gas-kWh	1
    water-heating-gas	wh-gas-kWh	1
    appliance-gas	ap-gas-kWh	1
    space-heating-oil	sh-oil-kWh	1
    water-heating-oil	wh-oil-kWh	1

Optionally, you can specify a colour column in the file to use to show the energy use by fuel type in a plot on the interface.

(11) The appliances fuel file gives the fuel used by households for each use of an appliance in each context. It has a heading row with columns "appliance" giving the name of the appliance, "category" and "subcategory" giving its classification, "household" giving the household type (file 4), "dwelling" giving the dwelling type (file 3), "tenure" giving the tenure (file 3), "purpose" giving the purpose for which the appliance is used, "mode" giving the usage-mode (file 7), "fuel" giving the type of fuel used, and "units 1" to "units <steps-per-year>" giving the number of units (as per file 10). The order of the columns is not important. Actual example file (steps-per-year = 4):

    appliance	category	subcategory	household	dwelling	tenure			purpose	mode	fuel	units 1	units 2	units 3	units 4
    oil-condensing-boiler-A	heating	oil-conboiler-sub	household	*	*		space-heating	*	space-heating-oil	2041	680	680	2041
    ...
    oil-condensing-boiler-A	heating	oil-conboiler-sub	household				flat-top-cavity-3	*	water-heating	*	water-heating-oil			961	961	961	961
    ...
    Teba TFR14	cooker	electric-cooker-sub	household	*	*	hob	*		appliance-elect	37	37	37	37
    Creda Capri C150E	cooker	electric-cooker-sub	household	*	*			hob	*	appliance-elect	37	37	37	37
    Beko DV 5631	cooker	electric-cooker-sub	household	*	*			hob	*	appliance-elect	37	37	37	37
    ...
    Teba TFR14	cooker	electric-cooker-sub	household	*	*	oven	*		appliance-elect	28	28	28	28
    Creda Capri C150E	cooker	electric-cooker-sub	household	*	*			oven	*	appliance-elect	28	28	28	28
    Beko DV 5631	cooker	electric-cooker-sub	household	*	*			oven	*	appliance-elect	28	28	28	28
    ...

Obviously the file has the potential to get very long. To assist with this, a wildcard (*) may be used for the dwelling, tenure and mode columns (the household column cannot currently use wildcards, as household-types-list has not yet been defined when this file is read in). Both heating systems and some non-heating appliances (cookers) can have multiple purposes. In the example, the space-heating purpose has different fuel consumption at different times of year. The water-heating use has different fuel consumptions for different types of dwelling; the space-heating use does not, as such differences are handled using the insulation file (see 13 below).

(12) The energy prices file gives energy prices for each fuel type and main kind of use (space-heating, water-heating, non-heating appliances) for each time-step (see the notes on the fuel file, 10 above). There is no functionality at present to create a market for energy suppliers. Fuel prices are instead exogenous time series. The first row lists the combinations of fuels and main uses; subsequent rows specify prices for a single time-step. Actual example file:

    space-heating-elect	water-heating-elect	appliance-elect	space-heating-gas			water-heating-gas	appliance-gas	space-heating-oil	water-heating-oil
    0.0706	0.0706	0.0706	0.0166	0.0166	0.0166	0.0173	0.0173
    0.0706	0.0706	0.0706	0.0166	0.0166	0.0166	0.0173	0.0173
    0.0706	0.0706	0.0706	0.0166	0.0166	0.0166	0.0173	0.0173
    0.0706	0.0706	0.0706	0.0166	0.0166	0.0166	0.0173	0.0173
    0.0699	0.0699	0.0699	0.0171	0.0171	0.0171	0.0193	0.0193
    0.0699	0.0699	0.0699	0.0171	0.0171	0.0171	0.0193	0.0193
    0.0699	0.0699	0.0699	0.0171	0.0171	0.0171	0.0193	0.0193
    0.0699	0.0699	0.0699	0.0171	0.0171	0.0171	0.0193	0.0193
    0.0702	0.0702	0.0702	0.0182	0.0182	0.0182	0.0142	0.0142
    0.0702	0.0702	0.0702	0.0182	0.0182	0.0182	0.0142	0.0142
    0.0702	0.0702	0.0702	0.0182	0.0182	0.0182	0.0142	0.0142
    0.0702	0.0702	0.0702	0.0182	0.0182	0.0182	0.0142	0.0142
    0.0709	0.0709	0.0709	0.0185	0.0185	0.0185	0.0173	0.0173
    ...

When the model runs out of rows, the last price will be used.

(13) The insulation file is used to give different insulation states, and their insulation factor for each dwelling type. The unique identifier for an insulation is given by its insulation state and dwelling type combined. Actual example file:

    insulation-state	fuel-use-factor	dwelling-type
    minimum		2.487	bung-det-cavity-1
    dg			2.211	bung-det-cavity-1
    loft100		1.987	bung-det-cavity-1
    loft270		1.693	bung-det-cavity-1
    dg-loft100		1.766	bung-det-cavity-1
    dg-loft270		1.504	bung-det-cavity-1
    cwi			1.975	bung-det-cavity-1
    dg-cwi		1.755	bung-det-cavity-1
    loft100-cwi		1.577	bung-det-cavity-1
    loft270-cwi		1.344	bung-det-cavity-1
    dg-loft100-cwi	1.402	bung-det-cavity-1
    dg-loft270-cwi	1.195	bung-det-cavity-1
    ...
    swi			5.983	house-det-solid-5
    dg-swi		5.381	house-det-solid-5
    loft100-swi		5.221	house-det-solid-5
    loft270-swi		4.835	house-det-solid-5
    dg-loft100-swi	4.695	house-det-solid-5
    dg-loft270-swi	4.348	house-det-solid-5
    minimum		14.354	house-det-solid-6+
    dg			12.908	house-det-solid-6+
    ...


(14) The insulation upgrade file is used to specify the insulation upgrades that are available. There is one line in this file for each possible upgrade for each dwelling type, giving the cost of the upgrade. Actual example file:

    dwelling-type	from-state	to-state	cost
    bung-det-cavity-1	minimum		dg		3700
    bung-det-cavity-1	minimum		loft270		500
    bung-det-cavity-1	minimum		cwi		500
    bung-det-cavity-1	loft100		dg-loft100	3700
    bung-det-cavity-1	loft100		loft270		500
    bung-det-cavity-1	loft100		loft100-cwi	500
    ...
    house-mid-solid-5	dg-loft270	dg-loft270-swi	5500
    house-mid-solid-5	loft270-swi	dg-loft270-swi	3700
    house-mid-solid-5	dg-loft100-swi	dg-loft270-swi	500
    house-mid-solid-6+	minimum		dg		3700
    house-mid-solid-6+	minimum		loft270		500
    house-mid-solid-6+	minimum		swi		5500
    ...

(15) [Optional] The insulation update file is used to specify changes to the insulation upgrades that are available. There is one line in this file for each update. An update can be one of three options: removing an upgrade option, adding an upgrade option, or changing the cost of an upgrade option. The cost is irrelevant when removing an upgrade option, so this can be indicated by an asterisk. Hypothetical example file:

    step,command,dwelling-type,from-state,to-state,cost
    20,remove,flat,no-cavity-wall,cavity-wall,*
    30,add,loft100mm,loft500mm,500
    30,add,loft270mm,loft500mm,500
    50,change,loft100mm,loft270mm,500


(16) The maximum in category files is used to place limits on how many appliances of each category each type of household may possess (if an appliance is about to be added in excess of this limit, the oldest item in the category will be sent to landfill first). There is one line for each type of household, with the first item on a line identifying the household type, and successive pairs of items identifying a category and setting the limit for that category. The limit should never be zero (a limit of zero or below will cause an error). If no limit is set in this file for a household type-category pair, no limit is enforced. Hypothetical example file:

    GLAM,fridge,1,freezer,1,cooker,1,TV,3,computer,6
    SINBAD,fridge,1,freezer,1,TV,2,computer,1

(17) The household initial appliance files assigns initial appliances to households. It is a CSV file with no header row; the first column is the name of the household or a colon-separated household and dwelling type/address list, the remaining columns are appliance names. Appliance lists applied to particular households are used once and thrown away. Appliance lists assigned to household and dwelling type/address lists are used each time a matching household needs initial appliances. The household and dwelling type/address list is either a two-element list of household type and dwelling id, or a three-element list of household type, tenure and dwelling type. The former allows configurations of initial appliances to be allocated to particular houses; the latter is a more general approach. The provision for specifying initial appliances for combinations of household type and specific address would allow for running the model with randomised or partially randomised mixes of types of household, without writing a new household initial appliance file on each occasion.

Hypothetical example file:

    hh-1,fridge-344,TV-13,TV-54,kettle-78
    hh-2,fridge-freezer-352,TV-85,PC-464,toaster-15
    DINK:owned:house,washing-machine-34,tumble-drier-1,kettle-78,kettle-42
    KIPPERS:house-3,TV-57,DVD-player-254,PC-587

(18) [Optional] The triggers file specifies conditions, pertaining to factors including but not limited to household finances or economic conditions, under which the goal-frame selected using the household’s value-strength parameters may be stochastically changed. Each row in a trigger file consists of five fields: an index integer ("trigger number") which, read by the procedure adjust-goal-frame, tells the model what type of condition is to be tested for before applying the trigger, a numerical value for use in the test, specifications of what the current goal-frame must be for the trigger to be applied, a goal-frame this may be changed to, and a probability of change if the trigger conditions are met. Actual file example:

    1	5	enjoy	gain	0.25
    2	20	gain	enjoy	0.25
    3	1.15	enjoy	gain	0.5
    4	1	gain	enjoy	0.25


(19) [Optional] The external influences file contains a schedule for the effect of influences on value-strength parameters from outwith the modelled community, representing government or NGO information campaigns, or public opinion. Each row in an external influences file consists of five fields: the time-step at which the influence is applied, the goal-frame which must be focal if it is to be applied, two value-strength parameters, and a numerical value representing the value-strength to be transferred from the first of this pair of parameters to the second. Actual example file:

    65	sustain	egoistic	biospheric	1.5
    67	gain	egoistic	biospheric	1
    69	sustain	egoistic	biospheric	1.5
    73	gain	egoistic	biospheric	1
    75	gain	egoistic	biospheric	1
    76	sustain	egoistic	biospheric	1.5
    77	sustain	egoistic	biospheric	1.5
    ...




## EXTENDING THE MODEL

There are numbers of ways in which the model could be improved to better reflect reality. The social links model is one way in particular that the model could be improved. Do people really make/break social links based on similarity of equipment profile? If they do, is the formula we have used for equipment similarity really right? Besides that, there are various enhancements to the model that could be made to add more sophistication:

* Different kinds of social link (Ernst's "network of networks") and differing influences they have on household behaviour.
* Using other theories of decision making besides goal frames.
* Splitting the household up into individual agents.
* Implementing moves and migration reflecting demographic changes (could draw on the Schelling model -- ghettoisation need not be just about race, but also class).
* Allowing building/development to take place (could draw on Dan Brown's work on greenbelts, for example), and with that, planning.
* Simulating home improvements (green or otherwise). This could be done by allowing dwelling-type to change, and having costs for doing so in a time series.
* Factoring in transport issues.

## NETLOGO FEATURES

The profiling facility of NetLogo is used to measure running speeds of the model with different spatial configurations and numbers of agents, to see how it performs. Click the "Profile" button to run the model for halt-after number of steps, and get a report of the execution time spent in each procedure. This can be useful for identifying areas of performance improvement in the model.

Extensive use has also been made of arrays and tables. Several data structures are such horrendous things as lists of tables of tables.

Breeds and link breeds have been used to make the ontology of the model as transparent as possible.

One particular irritation with NetLogo was in the development of the usage-mode and trigger functionality. Here we wanted to put in the relevant files some NetLogo code defining the conditions under which a particular usage-mode or trigger would apply. There seemed to be no way, even with the extension API, to create a situation in which that is possible. (In general, the extension API allows very little introspection on NetLogo itself, nor on agents and objects therein, and is not well documented.) This left us with the rather inelegant solution of having to predefine the conditions manually in procedures, and then have a series of conditionals in get-usage-mode testing each one.


## REFERENCES

Gotts, N.M. (2009) ABMED: A prototype model of energy demand. Sixth Conference of the European Social Simulation Association, University of Surrey, Guildford, 14-18 September 2009.

Gotts, N.M. and Polhill, J.G. (2014) The CEDSS Model of Direct Domestic Energy Demand. Paper presented at Social Simulation 2014, Barcelona 1-5 September 2014. Available online at http://fawlty.uab.cat/SSC2014/ESSA/socialsimulation2014_073.pdf.

Gotts, N.M. and Polhill, J.G. (forthcoming) Experiments with a model of domestic energy deamnd. Paper to be presented at SSC 2016, the 12th Conference of the European Social Simulation Association: Social Simulation Conference. 19th-23rd September 2016, Rome.

Gotts, N.M., Polhill, J.G., Craig, T. and C. Galan-Diaz, C. (2014) Combining Diverse Data Sources for CEDSS, an Agent-Based Model of Domestic Energy Demand, Structure and Dynamics: eJournal of Anthropological and Related Science, 7,(1):1-32,  http://escholarship.org/uc/item/62x9p0w4.

Lindenberg, S. and Steg, L. (2007) Normative, gain and hedonic goal-frames guiding environmental behaviour. Journal of Social Issues 63 (1): 117-137.

Polhill, J.G. and Gotts, N.M. (2015) How precise are the specifications of a psychological theory? Comparing implementations of Lindenberg and Steg’s Goal-Framing Theory of everyday pro-environmental behaviour. Paper presented at SSC 2015, the 11th Conference of the European Social Simulation Association: Social Simulation Conference. 14th-18th September 2015, Groningen, The Netherlands.

Steg, L., Bolderdijk, J. W., Keizer, K. and Perlavicute, G. (2014) An Integrated Framework for Encouraging Pro-environmental Behaviour: The role of values, situational factors and goals. Journal of Environmental Psychology 38, 104-115.


## LICENCE

GNU GENERAL PUBLIC LICENSE

Version 3, 29 June 2007

Copyright � 2007 Free Software Foundation, Inc. < http://fsf.org/ >

Everyone is permitted to copy and distribute verbatim copies of this license document, but changing it is not allowed.

Preamble

The GNU General Public License is a free, copyleft license for software and other kinds of works.

The licenses for most software and other practical works are designed to take away your freedom to share and change the works. By contrast, the GNU General Public License is intended to guarantee your freedom to share and change all versions of a program--to make sure it remains free software for all its users. We, the Free Software Foundation, use the GNU General Public License for most of our software; it applies also to any other work released this way by its authors. You can apply it to your programs, too.

When we speak of free software, we are referring to freedom, not price. Our General Public Licenses are designed to make sure that you have the freedom to distribute copies of free software (and charge for them if you wish), that you receive source code or can get it if you want it, that you can change the software or use pieces of it in new free programs, and that you know you can do these things.

To protect your rights, we need to prevent others from denying you these rights or asking you to surrender the rights. Therefore, you have certain responsibilities if you distribute copies of the software, or if you modify it: responsibilities to respect the freedom of others.

For example, if you distribute copies of such a program, whether gratis or for a fee, you must pass on to the recipients the same freedoms that you received. You must make sure that they, too, receive or can get the source code. And you must show them these terms so they know their rights.

Developers that use the GNU GPL protect your rights with two steps: (1) assert copyright on the software, and (2) offer you this License giving you legal permission to copy, distribute and/or modify it.

For the developers' and authors' protection, the GPL clearly explains that there is no warranty for this free software. For both users' and authors' sake, the GPL requires that modified versions be marked as changed, so that their problems will not be attributed erroneously to authors of previous versions.

Some devices are designed to deny users access to install or run modified versions of the software inside them, although the manufacturer can do so. This is fundamentally incompatible with the aim of protecting users' freedom to change the software. The systematic pattern of such abuse occurs in the area of products for individuals to use, which is precisely where it is most unacceptable. Therefore, we have designed this version of the GPL to prohibit the practice for those products. If such problems arise substantially in other domains, we stand ready to extend this provision to those domains in future versions of the GPL, as needed to protect the freedom of users.

Finally, every program is threatened constantly by software patents. States should not allow patents to restrict development and use of software on general-purpose computers, but in those that do, we wish to avoid the special danger that patents applied to a free program could make it effectively proprietary. To prevent this, the GPL assures that patents cannot be used to render the program non-free.

The precise terms and conditions for copying, distribution and modification follow.

TERMS AND CONDITIONS

0. Definitions.

�This License� refers to version 3 of the GNU General Public License.

�Copyright� also means copyright-like laws that apply to other kinds of works, such as semiconductor masks.

�The Program� refers to any copyrightable work licensed under this License. Each licensee is addressed as �you�. �Licensees� and �recipients� may be individuals or organizations.

To �modify� a work means to copy from or adapt all or part of the work in a fashion requiring copyright permission, other than the making of an exact copy. The resulting work is called a �modified version� of the earlier work or a work �based on� the earlier work.

A �covered work� means either the unmodified Program or a work based on the Program.

To �propagate� a work means to do anything with it that, without permission, would make you directly or secondarily liable for infringement under applicable copyright law, except executing it on a computer or modifying a private copy. Propagation includes copying, distribution (with or without modification), making available to the public, and in some countries other activities as well.

To �convey� a work means any kind of propagation that enables other parties to make or receive copies. Mere interaction with a user through a computer network, with no transfer of a copy, is not conveying.

An interactive user interface displays �Appropriate Legal Notices� to the extent that it includes a convenient and prominently visible feature that (1) displays an appropriate copyright notice, and (2) tells the user that there is no warranty for the work (except to the extent that warranties are provided), that licensees may convey the work under this License, and how to view a copy of this License. If the interface presents a list of user commands or options, such as a menu, a prominent item in the list meets this criterion.

(1) Source Code.

The �source code� for a work means the preferred form of the work for making modifications to it. �Object code� means any non-source form of a work.

A �Standard Interface� means an interface that either is an official standard defined by a recognized standards body, or, in the case of interfaces specified for a particular programming language, one that is widely used among developers working in that language.

The �System Libraries� of an executable work include anything, other than the work as a whole, that (a) is included in the normal form of packaging a Major Component, but which is not part of that Major Component, and (b) serves only to enable use of the work with that Major Component, or to implement a Standard Interface for which an implementation is available to the public in source code form. A �Major Component�, in this context, means a major essential component (kernel, window system, and so on) of the specific operating system (if any) on which the executable work runs, or a compiler used to produce the work, or an object code interpreter used to run it.

The �Corresponding Source� for a work in object code form means all the source code needed to generate, install, and (for an executable work) run the object code and to modify the work, including scripts to control those activities. However, it does not include the work's System Libraries, or general-purpose tools or generally available free programs which are used unmodified in performing those activities but which are not part of the work. For example, Corresponding Source includes interface definition files associated with source files for the work, and the source code for shared libraries and dynamically linked subprograms that the work is specifically designed to require, such as by intimate data communication or control flow between those subprograms and other parts of the work.

The Corresponding Source need not include anything that users can regenerate automatically from other parts of the Corresponding Source.

The Corresponding Source for a work in source code form is that same work.

(2) Basic Permissions.

All rights granted under this License are granted for the term of copyright on the Program, and are irrevocable provided the stated conditions are met. This License explicitly affirms your unlimited permission to run the unmodified Program. The output from running a covered work is covered by this License only if the output, given its content, constitutes a covered work. This License acknowledges your rights of fair use or other equivalent, as provided by copyright law.

You may make, run and propagate covered works that you do not convey, without conditions so long as your license otherwise remains in force. You may convey covered works to others for the sole purpose of having them make modifications exclusively for you, or provide you with facilities for running those works, provided that you comply with the terms of this License in conveying all material for which you do not control copyright. Those thus making or running the covered works for you must do so exclusively on your behalf, under your direction and control, on terms that prohibit them from making any copies of your copyrighted material outside their relationship with you.

Conveying under any other circumstances is permitted solely under the conditions stated below. Sublicensing is not allowed; section 10 makes it unnecessary.

(3) Protecting Users' Legal Rights From Anti-Circumvention Law.

No covered work shall be deemed part of an effective technological measure under any applicable law fulfilling obligations under article 11 of the WIPO copyright treaty adopted on 20 December 1996, or similar laws prohibiting or restricting circumvention of such measures.

When you convey a covered work, you waive any legal power to forbid circumvention of technological measures to the extent such circumvention is effected by exercising rights under this License with respect to the covered work, and you disclaim any intention to limit operation or modification of the work as a means of enforcing, against the work's users, your or third parties' legal rights to forbid circumvention of technological measures.

(4) Conveying Verbatim Copies.

You may convey verbatim copies of the Program's source code as you receive it, in any medium, provided that you conspicuously and appropriately publish on each copy an appropriate copyright notice; keep intact all notices stating that this License and any non-permissive terms added in accord with section 7 apply to the code; keep intact all notices of the absence of any warranty; and give all recipients a copy of this License along with the Program.

You may charge any price or no price for each copy that you convey, and you may offer support or warranty protection for a fee.

(5) Conveying Modified Source Versions.

You may convey a work based on the Program, or the modifications to produce it from the Program, in the form of source code under the terms of section 4, provided that you also meet all of these conditions:

a) The work must carry prominent notices stating that you modified it, and giving a relevant date.

b) The work must carry prominent notices stating that it is released under this License and any conditions added under section 7. This requirement modifies the requirement in section 4 to �keep intact all notices�.

c) You must license the entire work, as a whole, under this License to anyone who comes into possession of a copy. This License will therefore apply, along with any applicable section 7 additional terms, to the whole of the work, and all its parts, regardless of how they are packaged. This License gives no permission to license the work in any other way, but it does not invalidate such permission if you have separately received it.

d) If the work has interactive user interfaces, each must display Appropriate Legal Notices; however, if the Program has interactive interfaces that do not display Appropriate Legal Notices, your work need not make them do so.

A compilation of a covered work with other separate and independent works, which are not by their nature extensions of the covered work, and which are not combined with it such as to form a larger program, in or on a volume of a storage or distribution medium, is called an �aggregate� if the compilation and its resulting copyright are not used to limit the access or legal rights of the compilation's users beyond what the individual works permit. Inclusion of a covered work in an aggregate does not cause this License to apply to the other parts of the aggregate.

(6) Conveying Non-Source Forms.

You may convey a covered work in object code form under the terms of sections 4 and 5, provided that you also convey the machine-readable Corresponding Source under the terms of this License, in one of these ways:

a) Convey the object code in, or embodied in, a physical product (including a physical distribution medium), accompanied by the Corresponding Source fixed on a durable physical medium customarily used for software interchange.

b) Convey the object code in, or embodied in, a physical product (including a physical distribution medium), accompanied by a written offer, valid for at least three years and valid for as long as you offer spare parts or customer support for that product model, to give anyone who possesses the object code either (1) a copy of the Corresponding Source for all the software in the product that is covered by this License, on a durable physical medium customarily used for software interchange, for a price no more than your reasonable cost of physically performing this conveying of source, or (2) access to copy the Corresponding Source from a network server at no charge.

c) Convey individual copies of the object code with a copy of the written offer to provide the Corresponding Source. This alternative is allowed only occasionally and noncommercially, and only if you received the object code with such an offer, in accord with subsection 6b.

d) Convey the object code by offering access from a designated place (gratis or for a charge), and offer equivalent access to the Corresponding Source in the same way through the same place at no further charge. You need not require recipients to copy the Corresponding Source along with the object code. If the place to copy the object code is a network server, the Corresponding Source may be on a different server (operated by you or a third party) that supports equivalent copying facilities, provided you maintain clear directions next to the object code saying where to find the Corresponding Source. Regardless of what server hosts the Corresponding Source, you remain obligated to ensure that it is available for as long as needed to satisfy these requirements.

e) Convey the object code using peer-to-peer transmission, provided you inform other peers where the object code and Corresponding Source of the work are being offered to the general public at no charge under subsection 6d.

A separable portion of the object code, whose source code is excluded from the Corresponding Source as a System Library, need not be included in conveying the object code work.

A �User Product� is either (1) a �consumer product�, which means any tangible personal property which is normally used for personal, family, or household purposes, or (2) anything designed or sold for incorporation into a dwelling. In determining whether a product is a consumer product, doubtful cases shall be resolved in favor of coverage. For a particular product received by a particular user, �normally used� refers to a typical or common use of that class of product, regardless of the status of the particular user or of the way in which the particular user actually uses, or expects or is expected to use, the product. A product is a consumer product regardless of whether the product has substantial commercial, industrial or non-consumer uses, unless such uses represent the only significant mode of use of the product.

�Installation Information� for a User Product means any methods, procedures, authorization keys, or other information required to install and execute modified versions of a covered work in that User Product from a modified version of its Corresponding Source. The information must suffice to ensure that the continued functioning of the modified object code is in no case prevented or interfered with solely because modification has been made.

If you convey an object code work under this section in, or with, or specifically for use in, a User Product, and the conveying occurs as part of a transaction in which the right of possession and use of the User Product is transferred to the recipient in perpetuity or for a fixed term (regardless of how the transaction is characterized), the Corresponding Source conveyed under this section must be accompanied by the Installation Information. But this requirement does not apply if neither you nor any third party retains the ability to install modified object code on the User Product (for example, the work has been installed in ROM).

The requirement to provide Installation Information does not include a requirement to continue to provide support service, warranty, or updates for a work that has been modified or installed by the recipient, or for the User Product in which it has been modified or installed. Access to a network may be denied when the modification itself materially and adversely affects the operation of the network or violates the rules and protocols for communication across the network.

Corresponding Source conveyed, and Installation Information provided, in accord with this section must be in a format that is publicly documented (and with an implementation available to the public in source code form), and must require no special password or key for unpacking, reading or copying.

(7) Additional Terms.

�Additional permissions� are terms that supplement the terms of this License by making exceptions from one or more of its conditions. Additional permissions that are applicable to the entire Program shall be treated as though they were included in this License, to the extent that they are valid under applicable law. If additional permissions apply only to part of the Program, that part may be used separately under those permissions, but the entire Program remains governed by this License without regard to the additional permissions.

When you convey a copy of a covered work, you may at your option remove any additional permissions from that copy, or from any part of it. (Additional permissions may be written to require their own removal in certain cases when you modify the work.) You may place additional permissions on material, added by you to a covered work, for which you have or can give appropriate copyright permission.

Notwithstanding any other provision of this License, for material you add to a covered work, you may (if authorized by the copyright holders of that material) supplement the terms of this License with terms:

a) Disclaiming warranty or limiting liability differently from the terms of sections 15 and 16 of this License; or

b) Requiring preservation of specified reasonable legal notices or author attributions in that material or in the Appropriate Legal Notices displayed by works containing it; or

c) Prohibiting misrepresentation of the origin of that material, or requiring that modified versions of such material be marked in reasonable ways as different from the original version; or

d) Limiting the use for publicity purposes of names of licensors or authors of the material; or

e) Declining to grant rights under trademark law for use of some trade names, trademarks, or service marks; or

f) Requiring indemnification of licensors and authors of that material by anyone who conveys the material (or modified versions of it) with contractual assumptions of liability to the recipient, for any liability that these contractual assumptions directly impose on those licensors and authors.

All other non-permissive additional terms are considered �further restrictions� within the meaning of section 10. If the Program as you received it, or any part of it, contains a notice stating that it is governed by this License along with a term that is a further restriction, you may remove that term. If a license document contains a further restriction but permits relicensing or conveying under this License, you may add to a covered work material governed by the terms of that license document, provided that the further restriction does not survive such relicensing or conveying.

If you add terms to a covered work in accord with this section, you must place, in the relevant source files, a statement of the additional terms that apply to those files, or a notice indicating where to find the applicable terms.

Additional terms, permissive or non-permissive, may be stated in the form of a separately written license, or stated as exceptions; the above requirements apply either way.

(8) Termination.

You may not propagate or modify a covered work except as expressly provided under this License. Any attempt otherwise to propagate or modify it is void, and will automatically terminate your rights under this License (including any patent licenses granted under the third paragraph of section 11).

However, if you cease all violation of this License, then your license from a particular copyright holder is reinstated (a) provisionally, unless and until the copyright holder explicitly and finally terminates your license, and (b) permanently, if the copyright holder fails to notify you of the violation by some reasonable means prior to 60 days after the cessation.

Moreover, your license from a particular copyright holder is reinstated permanently if the copyright holder notifies you of the violation by some reasonable means, this is the first time you have received notice of violation of this License (for any work) from that copyright holder, and you cure the violation prior to 30 days after your receipt of the notice.

Termination of your rights under this section does not terminate the licenses of parties who have received copies or rights from you under this License. If your rights have been terminated and not permanently reinstated, you do not qualify to receive new licenses for the same material under section 10.

(9) Acceptance Not Required for Having Copies.

You are not required to accept this License in order to receive or run a copy of the Program. Ancillary propagation of a covered work occurring solely as a consequence of using peer-to-peer transmission to receive a copy likewise does not require acceptance. However, nothing other than this License grants you permission to propagate or modify any covered work. These actions infringe copyright if you do not accept this License. Therefore, by modifying or propagating a covered work, you indicate your acceptance of this License to do so.

(10) Automatic Licensing of Downstream Recipients.

Each time you convey a covered work, the recipient automatically receives a license from the original licensors, to run, modify and propagate that work, subject to this License. You are not responsible for enforcing compliance by third parties with this License.

An �entity transaction� is a transaction transferring control of an organization, or substantially all assets of one, or subdividing an organization, or merging organizations. If propagation of a covered work results from an entity transaction, each party to that transaction who receives a copy of the work also receives whatever licenses to the work the party's predecessor in interest had or could give under the previous paragraph, plus a right to possession of the Corresponding Source of the work from the predecessor in interest, if the predecessor has it or can get it with reasonable efforts.

You may not impose any further restrictions on the exercise of the rights granted or affirmed under this License. For example, you may not impose a license fee, royalty, or other charge for exercise of rights granted under this License, and you may not initiate litigation (including a cross-claim or counterclaim in a lawsuit) alleging that any patent claim is infringed by making, using, selling, offering for sale, or importing the Program or any portion of it.

(11) Patents.

A �contributor� is a copyright holder who authorizes use under this License of the Program or a work on which the Program is based. The work thus licensed is called the contributor's �contributor version�.

A contributor's �essential patent claims� are all patent claims owned or controlled by the contributor, whether already acquired or hereafter acquired, that would be infringed by some manner, permitted by this License, of making, using, or selling its contributor version, but do not include claims that would be infringed only as a consequence of further modification of the contributor version. For purposes of this definition, �control� includes the right to grant patent sublicenses in a manner consistent with the requirements of this License.

Each contributor grants you a non-exclusive, worldwide, royalty-free patent license under the contributor's essential patent claims, to make, use, sell, offer for sale, import and otherwise run, modify and propagate the contents of its contributor version.

In the following three paragraphs, a �patent license� is any express agreement or commitment, however denominated, not to enforce a patent (such as an express permission to practice a patent or covenant not to sue for patent infringement). To �grant� such a patent license to a party means to make such an agreement or commitment not to enforce a patent against the party.

If you convey a covered work, knowingly relying on a patent license, and the Corresponding Source of the work is not available for anyone to copy, free of charge and under the terms of this License, through a publicly available network server or other readily accessible means, then you must either (1) cause the Corresponding Source to be so available, or (2) arrange to deprive yourself of the benefit of the patent license for this particular work, or (3) arrange, in a manner consistent with the requirements of this License, to extend the patent license to downstream recipients. �Knowingly relying� means you have actual knowledge that, but for the patent license, your conveying the covered work in a country, or your recipient's use of the covered work in a country, would infringe one or more identifiable patents in that country that you have reason to believe are valid.

If, pursuant to or in connection with a single transaction or arrangement, you convey, or propagate by procuring conveyance of, a covered work, and grant a patent license to some of the parties receiving the covered work authorizing them to use, propagate, modify or convey a specific copy of the covered work, then the patent license you grant is automatically extended to all recipients of the covered work and works based on it.

A patent license is �discriminatory� if it does not include within the scope of its coverage, prohibits the exercise of, or is conditioned on the non-exercise of one or more of the rights that are specifically granted under this License. You may not convey a covered work if you are a party to an arrangement with a third party that is in the business of distributing software, under which you make payment to the third party based on the extent of your activity of conveying the work, and under which the third party grants, to any of the parties who would receive the covered work from you, a discriminatory patent license (a) in connection with copies of the covered work conveyed by you (or copies made from those copies), or (b) primarily for and in connection with specific products or compilations that contain the covered work, unless you entered into that arrangement, or that patent license was granted, prior to 28 March 2007.

Nothing in this License shall be construed as excluding or limiting any implied license or other defenses to infringement that may otherwise be available to you under applicable patent law.

(12) No Surrender of Others' Freedom.

If conditions are imposed on you (whether by court order, agreement or otherwise) that contradict the conditions of this License, they do not excuse you from the conditions of this License. If you cannot convey a covered work so as to satisfy simultaneously your obligations under this License and any other pertinent obligations, then as a consequence you may not convey it at all. For example, if you agree to terms that obligate you to collect a royalty for further conveying from those to whom you convey the Program, the only way you could satisfy both those terms and this License would be to refrain entirely from conveying the Program.

(13) Use with the GNU Affero General Public License.

Notwithstanding any other provision of this License, you have permission to link or combine any covered work with a work licensed under version 3 of the GNU Affero General Public License into a single combined work, and to convey the resulting work. The terms of this License will continue to apply to the part which is the covered work, but the special requirements of the GNU Affero General Public License, section 13, concerning interaction through a network will apply to the combination as such.

(14) Revised Versions of this License.

The Free Software Foundation may publish revised and/or new versions of the GNU General Public License from time to time. Such new versions will be similar in spirit to the present version, but may differ in detail to address new problems or concerns.

Each version is given a distinguishing version number. If the Program specifies that a certain numbered version of the GNU General Public License �or any later version� applies to it, you have the option of following the terms and conditions either of that numbered version or of any later version published by the Free Software Foundation. If the Program does not specify a version number of the GNU General Public License, you may choose any version ever published by the Free Software Foundation.

If the Program specifies that a proxy can decide which future versions of the GNU General Public License can be used, that proxy's public statement of acceptance of a version permanently authorizes you to choose that version for the Program.

Later license versions may give you additional or different permissions. However, no additional obligations are imposed on any author or copyright holder as a result of your choosing to follow a later version.

(15) Disclaimer of Warranty.

     THERE IS NO WARRANTY FOR THE PROGRAM, TO THE EXTENT PERMITTED BY APPLICABLE LAW.
     EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
     PROVIDE THE PROGRAM �AS IS� WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR
     IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
     FITNESS FOR A PARTICULAR PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE
     OF THE PROGRAM IS WITH YOU. SHOULD THE PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST
     OF ALL NECESSARY SERVICING, REPAIR OR CORRECTION.

(16) Limitation of Liability.

     IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING WILL ANY
     COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MODIFIES AND/OR CONVEYS THE PROGRAM AS
     PERMITTED ABOVE, BE LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL,
     INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE
     PROGRAM (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING RENDERED INACCURATE
     OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A FAILURE OF THE PROGRAM TO OPERATE
     WITH ANY OTHER PROGRAMS), EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE
     POSSIBILITY OF SUCH DAMAGES.

(17) Interpretation of Sections 15 and 16.

If the disclaimer of warranty and limitation of liability provided above cannot be given local legal effect according to their terms, reviewing courts shall apply local law that most closely approximates an absolute waiver of all civil liability in connection with the Program, unless a warranty or assumption of liability accompanies a copy of the Program in return for a fee.

END OF TERMS AND CONDITIONS

How to Apply These Terms to Your New Programs

If you develop a new program, and you want it to be of the greatest possible use to the public, the best way to achieve this is to make it free software which everyone can redistribute and change under these terms.

To do so, attach the following notices to the program. It is safest to attach them to the start of each source file to most effectively state the exclusion of warranty; and each file should have at least the �copyright� line and a pointer to where the full notice is found.

        <one line to give the program's name and a brief idea of what it does.>
        Copyright (C) <year>  <name of author>

        This program is free software: you can redistribute it and/or modify
        it under the terms of the GNU General Public License as published by
        the Free Software Foundation, either version 3 of the License, or
        (at your option) any later version.

        This program is distributed in the hope that it will be useful,
        but WITHOUT ANY WARRANTY; without even the implied warranty of
        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
        GNU General Public License for more details.

        You should have received a copy of the GNU General Public License
        along with this program.  If not, see < http://www.gnu.org/licenses/ >.

Also add information on how to contact you by electronic and paper mail.

If the program does terminal interaction, make it output a short notice like this when it starts in an interactive mode:

        <program>  Copyright (C) <year>  <name of author>
        This program comes with ABSOLUTELY NO WARRANTY; for details type `show w'.
        This is free software, and you are welcome to redistribute it
        under certain conditions; type `show c' for details.

The hypothetical commands `show w' and `show c' should show the appropriate parts of the General Public License. Of course, your program's commands might be different; for a GUI interface, you would use an �about box�.

You should also get your employer (if you work as a programmer) or school, if any, to sign a �copyright disclaimer� for the program, if necessary. For more information on this, and how to apply and follow the GNU GPL, see < http://www.gnu.org/licenses/ >.

The GNU General Public License does not permit incorporating your program into proprietary programs. If your program is a subroutine library, you may consider it more useful to permit linking proprietary applications with the library. If this is what you want to do, use the GNU Lesser General Public License instead of this License. But first, please read < http://www.gnu.org/philosophy/why-not-lgpl.html >.

## CHANGE LOG

2016-07-19 Nick Gotts
Changes to comments.

2016-07-17 Nick Gotts
Changes to comments.

2016-07-15 Nick Gotts
Extensive changes to comments, and some rearrangment of the order of procedures.

2016-07-14 Nick Gotts
Removed all code concerned with household turnover. It has not been used, and would now require considerable change to function correctly with the rest of the model - specifically to deal with the change from a single value for household income per step ("steply-net-income") to apply throughout a run, to a list of values, one per step. This edit included changes to the list of global variables, to what households own, and to setup-files, setup-globals, read-households-file, setup-households, step, income-this-step, and update-globals; as well as complete removal of read-inmigrant-file, transition-household-state, resample-parameters, and sample.

2016-07-10 Nick Gotts
Corrected errors in update-insulation-upgrades, to allow it to process items in the insulation-updates file correctly.

2014-11-30 Nick Gotts
* Removed two calls to plot-pen-reset from my-update-plots. These were interfering with correct plotting of appliance subcategory ownership and insulation-state time-series.
* Removed default pen settings from subcategory ownership and insulation-state plots on the interface. These were generating redundant entries in the csv files produced by my-export-all-plots.

2014-11-26 Nick Gotts
* Amended read-triggers and read-external-influences so the globals triggers-list and external-influences-list are correctly set to [] if the corresponding file argument is null.

2014-11-25 Nick Gotts
* Tidied interface.

2014-11-09 Nick Gotts
* Amended gain-link so it only adds a link if the number it already has is less than the maximum  (formerly it was less than or equal to).
* Renamed read-csv as read-csv-with-headings.
* Renamed suppliers-file as energy-prices-file, read-suppliers-file as read-energy-prices-file, and removed the code from read-energy-prices-file that reads and throws away the first line, which was a list of names of "suppliers" nowhere mentioned in the model.
* Made a couple of changes substituting use of fput for sentence in new code.
* Updated show-licence-message.

2014-11-08 Nick Gotts
* Amended determine-patch-type-blocks to make it act as intended: the "foreach idlist" loop was doing nothing: simply setting the block-id of patches to what they already were. In fact, this only caused one error for the current layout: the empty area at the top of the layout became two blocks instead of one.
* Amended make-patch-social-links-type, make-patch-type-social-links-type and make-radius-social-links-type so they check that a household has not reached the maximum-links limit before creating a new one. (Failure to do this was not an error, but there is no obvious reason why initial allocations of social links should be allowed to exceed the maximum).
* Amended replace-broken-appliances so households that rent get their essential appliances replaced free, as intended: the test for tenure being "rented" was faulty.
* Amended update-wish-list to shuffle (randomise) the list of members of a new subcategory.
* Amended step and update-wish-list for clarity. It is now clear from step that visits-per-step visits will be made whatever the goal-frame - unless the household has no social contacts; update-wish-list is now passed a list of visits made, which it uses to update the wish-list, rather than returning a list of visits made as a side-effect.
* Amended calculate-projected-space-heating-cost-over-planning-horizon and calculate-current-space-heating-cost so that the correction for the dwelling's insulation-factor is carried out in the latter, not the former, so that the latter does actually return the calculated current heating cost.

2014-11-07 Nick Gotts
* Amended update-globals to ensure that all the elements of energy-price-list get used: the current version was only using the first half of them.
* Added global variable triggers-list, and procedures read-triggers (called from setup-globals) and adjust-goal-frame (called from step), to implement the ability to model the effect of current circumstances on the identity of the current goal-frame. An input was also added to the interface, for the name of the external-influences file. The procedure adjust-goal-frame uses the same approach as get-usage-mode: specific types of trigger need to be hard-coded into this procedure, as NetLogo does not provide the facility to use procedures as arguments to other procedures. The trigger may be either a condition the household meets, or something in the wider environment; the triggers-list is a list of 5-element lists, each consisting of an identiying integer (used to find the appropriate conditional clause in adjust-goal-frame), an optional argument to be accessed by the clause in adjust-goal-frame, the goal-frame the household must be in for the trigger to operate, the goal-frame the trigger may switch it to, and a probability that the switch will occur if the conditions of the clause are met. The triggers currently coded for are capital-reserve being below or above a multiple of income-this-step (triggering a switch from "enjoy" to "gain" goal-frame or vice versa), and percentage rises or falls in the price of the household's heating fuel between the previous and current timestep, again triggering a switch from "enjoy" to "gain" goal-frame or vice versa. Note that a change of goal-frame by adjust-goal-frame does not alter value-strengths.

2014-11-06 Nick Gotts
* Amended value-adjust to set biospheric value-strength correctly: it had been setting it simply to the value of the adjustment to be made.
* Amended visit so that it correctly adjusts the host's values if reciprocal-adjustment is set to "true": it had been "adjusting" the values relative to itself.
* Added procedure biospheric-boost, and code in replace-broken-appliances, sustain-equip-nonessential, and sustain-insulation to call it. When a purchase is made in the biospheric goal-frame, the bioospheric value strength is increased (and the other value-strengths decreased in compensation), by an amount proportional to the cost. The proportion to use is set by the global variable biospheric-boost-factor.
* Renamed procedures enjoy-ess, gain-ess and sustain-ess to enjoy-ess-choose-replacement, gain-ess-choose-replacement and sustain-ess-choose-replacement, for clarity.

2014-11-05 Nick Gotts
Added global variable external-influences-list, and procedures read-external-influences (called from setup-globals) and absorb-external-influences (called from step), to implement the ability to model external (governmental or civil society) influences on value strengths. An input was also added to the interface, for the name of the external-influences file. The external-influences-list is a list of 5-element lists, the elements being a time-step when the sublist is to be used, a goal-frame which a household must be within for the element to apply to it, two values, and an amount of strength to be transfered from the first of these to the second.

2014-11-04 Nick Gotts
* Removed unnecessary line "let hh-horizon [planning-horizon] of hh" from heating-system-cost-advice.
* Moved update-insulation-upgrades from step to go: it's a global process, which should not be repeated for every household.
* Renamed the goal-frames, and the household value variables, to make them readily distinguishable, and closer to usage within goal-frame theory. Values are now “hedonic”, “egoistic” and “biospheric” (these terms will also need to be used in household input files); the corresponding goal-frames are “enjoy”, “gain” and “sustain”. Procedures which included the elements “hedonistic”, and “norm” have also been renamed, uisng “enjoy” and “sustain” respectively. The “-equip” procedures have also had the element “-nonessential” tagged on for clarity.

2014-11-03 Nick Gotts
* Removed buy-new-appliances, moving its functionality into step, from which it was called. All buy-new-appliances did was call one of three other procedures, depending on the current goal-frame; the code is clearer without it. Procedures hedonistic-equip, gain-equip and norm-equip renamed as hedonistic-equip-nonessentail, are now called directly from step.
* Removed unused code to assign initial appliances from read-household-file. This is done in read-initial-appliances-file.
* Removed code from read-social-links-matrix-file allowing it to add household-types or dwelling-types, replacing it with error message code if an unrecognised dwelling-type or household-type is referenced.
* Amended read-energy-suppliers to remove code dealing with the possibility of incorporating an energy market, with multiple suppliers of each tpye of fuel, into CEDSS. If we ever want to do this, considerable code changes will be needed. Also swapped the order in the file of read-fuel and read-energy-suppliers - read-fuel is called first, and establishes the types of fuels for read-energy-suppliers.

2014-11-02 Nick Gotts
* Amended gain-insulation, norm-insulation and insulation-factor to reflect the fact that a dwelling always has a single insulation, incorporating the effects of all the insulation measures applied to it; not a set of insulations, the effects of which had to be multiplied. This should make no difference to the outcome, but simplifies the code.
* Noticed anomalies in the plotting of appliance category and subcategory numbers, with some plot-lines stopping short. Restored the "apparently unnecessary" calls to sort in setup removed on 2014-10-30 (before "remove-duplicates"), and added another such call in setup, and two in my-update-plots. This should ensure that lists of categories and subcategories used in plotting are always in the same order.
* Removed a long comment about a temporary fix, and commented-out code, from add-item-cost-free; the temporary fix was superceded in the version of 2012-03-26, but this was not noted at the time. A note has been added to the change log with that date.
* Amended update-links and gain-link so that either lose-link or gain-link is always called (the call to gain-link had depended on the maximum number of links not having been reached). Further amended gain-link so it would always add a link unless the maximum number of links had been reached, or there were no households to which the given household was not linked.

2014-10-31 Nick Gotts
* Changed all instances of "first-step-available" which referred to households rather than appliances to "first-step-resident", to avoid confusion.
* Amended calculate-moeu so that a household saves money (as well as recording lower energy use) when adding insulation! Cost calculations as well as energy use calculation now involve multiplying the calculated amount by cons-ins-factor, which will be 1 for all consumptions except space-heating, but less than 1 for space-heating if there is more than minimum insulation. It appears this was forgotten when the procedure was updated to take account of insulation between 2011-09-14 and 2011-09-28. Note that calculate-projected-running-cost already made this adjustment.
* Changed name of argument to current-replacements-for-appliances-to-be-replaced from "household-agent" to "hh", as is used for households elsewhere.
* Changed error-message from calculate-current-space-heating-cost to be more informative.
* Added error message to heating-system-cost-advice for the case where there is no replacement for a broken heating-system.
* Amended hedonistic-equip again, to ensure replaacements for broken items get top priority.
* Amended replace-broken-appliances to call gain-ess-replace not hedonistic-ess-replace when landlord is replacing an essential items for tenant household, so the landlord minimises cost.
* Further tidying of comments.

2014-10-30 Nick Gotts
* Removed the (commented out) breed "supplier" and link-breeds "supplies" and "similarities".
* Tidied up comments.
* Replaced __clear-all-and-reset-ticks with clear-all in setup, as per a comment from Gary.
* Removed two apparently unnecessary calls to sort from setup (context: "sort remove-duplicates...).
* Removed all references to "total-links".

2014-10-29 Nick Gotts
* Removed from update-wish-list the code adding a replacement for a single old but not broken item to the wish-list. Logically, this code should have been complemented by code marking the old item as to be discarded if replaced, but there is no such code. Moreover, it had been necessary to modify the code to prevent essential items being chosen for replacement (for consistency in how such items are treated if the household rents its dwelling). It is unlikely the code had much effect, because new items are added to the wish-list via other mechanisms, and old appliances preferentially discarded if the limits on the numbers of appliances in specific categories are breached.
* Also amended update-wish-list so an item can be added to the wish-list on each of visits-per-step visits to social contacts, not just on one of these visits.
* Added a global variable all-insulation-states, set by read-insulation-file, and used by my-update-plots. The insulation plot was previously malfunctioning, because it took the set of insulation-states to update from those that were currently to be found in at least one dwelling.
* Removed the following unused procedures (some were already commented out): current-appliances-i-can-afford, appliances-household-can-afford,appliances-i-can-afford,
appliances-to-be-replaced, current-replacements-for-my-appliance, current-replacements-for-appliances-i-don’t-have-owned-by, similarity-sum, mean-links, n-household, read-appliance-similarity, assign-replacements, read-text.
* Removed the following unused global variables: equipment-descriptor-scores, patchset-data, energy-use, steps-all-household-total-electricity-use, steps-all-household-total-gas-use, steps-all-household-total-coal-use, steps-all-household-total-oil-use, steps-all-household-total-LPG-use.

2014-10-27 Nick Gotts
* The change of 2014-10-23 led to an error, with one-of complaining of an empty list as argument. The problem was traced to update-globals, where the code for setting new-appliance-subcategories was including subcategories which would not include any appliances yet available.

2014-10-23 Nick Gotts
* Change to hedonistic-equip, removing the addition of an item to the list of its current-replacements (because current-replacements-for ensures the item itself is included if it is currently available, and otherwise, it should not be added).

2014-10-22 Nick Gotts
* Change to hedonistic-equip, in which an error was discovered (drawing an item to acquire from "choice-list" instead of "affordable-choice-list") which would lead to the same item being chosen repeatedly. Further changes made to add a single item from the list of current-replacements-for each broken item to the choice-list rather than all such replacements, and to make the code clearer by avoiding reversing lists.
* Changed hedonistic-ess-replace and gain-ess-replace so the latter, not the former, chooses the cheapest replacement; and the former, not the latter, selects an item at random.

2014-02-23 Nick Gotts
* Change update-wish-list so that one item per visit is added to the wish-list (as I
think was intended).

2014-02-21 Nick Gotts
* Added plots for "Appliance subcategories" and "Insulation states".

2012-04-15 Nick Gotts
* Added procedures calculate-appliance-energy-use and calculate-heating-energy-use, added global variables steps-all-household-appliance-energy-use andsteps-all-household-heating-energy-use which these procedures reset at the end of each step, and caused their values and the elapsed time in seconds to be output-printedeach step.

2012-04-14 Gary Polhill
* Changed to compute the current-appliances at the start of each 'go', saving them being recomputed each time current-replacements-for and current-replacements-for-appliances-to-be-replaced is called.

2012-04-06 Gary Polhill
* Added the my-export-all-plots procedure

2012-04-02 Gary Polhill
* Moved the bottom four plots to the right hand side of the space on the interface. Moved the maximum-in-category-file text box above the household-init-appliance-file text box to make room for the plots.

2012-04-01 Nick Gotts
* Edited replace-broken-appliances so that for a household with "rented" tenure, an essential appliance is replaced free only if there are no unbroken appliances in the same category.

2012-03-27 Nick Gotts
* Changed choose-goal-frame so that habit-adjustment-factor is added to the "successful" goal-frame parameter on each step, rather than multiplied with it. The other two goal-frame parameters are reduced accordingly, each by half the habit-adjustment-factor if possible. If these changes would make any of the goal-frame parameters negative, or greater than the sum of the three goal-frame parameters before the changes, the magnitude of the changes is reduced so that this is no longer the case.
* Altered code so that use-social-links is set to True iff social-link-matrix-file is a non-null, non-false and non-zero-length filename. Social links will then be used iff use-social-links is True. This has the same effect as the change made on 2012-03-25, but is more efficient.

2012-03-26 but added 2014-11-02 Nick Gotts
* In the version of this date, list-to-table was added to use read-from-string when
acquiring table values from a file, so that if the intended value is a number, list, boolen-value or the special value nobody, it will be stored correctly.

2012-03-25 Nick Gotts
* Changed choose-goal-frame so that when a household chooses a goal-frame, it multiplies its propensity to choose that goal frame ("hedonism", "greenness", or "gain-orientation") by the habit-adjustment factor.
* Changed global variable name "new-category-steps" to "new-subcategory-steps", as it concerns subcategories of appliances, not categories.
* Altered code in several places so that even if use-social-links is True, no attempt will be made to use them unless a valid, non-null social-links-matrix-file is named. This was to make Behavior Space runs easier.

2012-03-23 Gary Polhill
* Changed read-social-link-matrix-file so that new dwelling types were added to the dwelling types list even if they did not appear in the first line (fixing what looked like a bug)
* Changed read-social-link-matrix-file so that it did not add household '*' or dwelling type '*' to the lists, so that these could be used as wildcards.
* Changed make-random-social-links to cope with wildcards, extracting make-random-social-links-type.
* Changed make-patch-social-links to cope with wildcards, extracting make-patch-social-links-type.
* Changed make-radius-social-links to cope with wildcards, extracting make-radius-social-links-type.
* Changed make-patch-type-social-links to cope with wildcards, extracting make-patch-type-social-links-type.

2012-03-20 Nick Gotts
At this point, as the program runs successfully after several small-to-midscale changes, it is renamed CEDSS3.3.

2012-03-20 Nick Gotts
Corrected a bug in add-item-cost-free: when acquiring a new item means the limit for that category is exceeded, this was adding an ownership to the land-fill, not an appliance. This caused an error in my-update-plots.

2012-03-19 Nick Gotts
Altered add-item-cost-free so that limits on the number of a category of appliance which a type of household can possess are treated as numbers not strings, which was causing an error. This is a temporary fix: the process of reading in maximum-in-category-table produces strings where integers are wanted. This problem was not discovered previously because the maximum-in-category-file being used had no categories in common with appliances file.

2012-03-19 Nick Gotts
Added a switch "fill-empty-properties" to the interface, and changed read-inmigrant-file to access it. If it is true, this acts as before; otherwise, empty properties are left unfilled. Also altered show-changes to allow for empty properties. These are coloured "gray".

2012-03-19 Nick Gotts
Altered read-appliances-fuel-use so that the "household" column cannot contain a wildcard "*": when this was allowed, actual use of the wildcard generated an error, as the household-types-list is required but has not yet been set (a consequence of reversing the order of setup-households and setup-appliances). Also added a number of output-print statements (some now commented out) for diagnostic purposes.

2012-03-19 Gary Polhill
* Added diagnostic to error message "no insulation..." in read-dwellings
* Added file-close-all to setup

2012-03-18 Nick Gotts
Simplified the measurement of appliance similarity between a pair of households to the number of appliances they have in common, minus the number one has and the other does not. This means neither same-appliance-similarity nor the appliance similarity file is needed.

2012-03-17 Nick Gotts
For convenience in constructing input files, commented out part of read-replacements which throws an error if item A is listed as a possible replacement for itself, or for item B while A is only available at times before B is available, and hence will never replace it. For the former, the item is now simply ignored. For thew latter, since a check is always carried out that a putative replacement is available at the current step, allowing such "temporally impossible replacements" to appear in the file does not matter functionally.

2012-03-17 Nick Gotts
commented out the procedure assign-replacements, which is not used.

2012-03-11 Nick Gotts
Change hedonistic-ess-replace so it selects from available alternatives at random.

2012-03-11 Nick Gotts
Altered norm-cost so appliances with lower numbers in their energy-rating property are preferred - in line with numberings in some of the CC questions.

2012-03-08 Nick Gotts
Changes so that household incomes are specified using lists of values rather than single values or distributions from which a single value is taken. Instread of a single value for steply income, a household has a list of values (the property name remains steply-net-income), and also has a property first-step-available, which is set when it is created to the step at which this occurs.  New procedure: toreport income-this-step which retreives the income for a given step from the list of incomes associated with the household. Other procedures affected: resample-parameters, calculate-finance, appliances-i-can-afford, hedonistic-equip, read-households-file.

2012-02-21 Nick Gotts
Added a global variable habit-adjustment-factor. Every time-step, when a household chooses a goal-frame, it multiplies the strength of that goal frame by this factor, which will generally be slightly more than 1. The point of this is to counter the tendency of the goal-frame strengths of different households to come closer to each other over time, as adjustments to goal-frame strengths are made during visits.

2012-02-13 Nick Gotts
Altered appliances to take a list of costs (cost-list) instead of a single cost, allowing cost to change over the period an appliance is available. The first cost listed refers to the first time-step (tick) at which the appliance is available for purchase, with subsequent costs applying to subsequent time-steps; if the item remains available when the cost-list is exhausted, the final cost is assumed to continue to apply. The procedure cost-this-step was added to extract a cost at a given time-step, and all procedures accessing the cost of an appliance were amended accordingly.

2011-11-18 Nick Gotts
* Added checks to setup-households and allocate-initial-appliances, ensuring that
if household-init-appliance-file is "null", the program still runs.

2011-11-08 Gary Polhill
* Added initial-hh-appliances, initial-hh-address-appliances and initial-hh-dw-type-appliances. Added household-init-appliance-file, read-initial-appliances-file and allocate-initial-appliances.
* Fixed bug in resample-parameters that looked for household-type in named-in-migrants instead of household-id  .
* Added reallocation of appliances to resample-parameters.

2011-10-27 Nick Gotts
* Corrected bug in make-patch-social-links: the former version tried to link households to themselves.

2011-10-18 Nick Gotts
* Made the system of replacing all broken essential appliances in replace-broken-appliances the same as for heating, when the tenure ends in "rented": the landlord supplies the cheapest replacement without charge to the household. Also changed update-wish-list so that no essential items are selected for replacement if they are not broken, but just old. This was to make the treatment of essential items consistent when the tenure ends in "rented".

2011-10-15 Nick Gotts
* Changed the system of removing items which have been superceded by a newly bought item,
in procedure add-item-without-cost. This had involved removing all the items for which a new item was a possible replacement. THe new system places a limit on the number of items
belonging to a category a given type of household may have. If, with the new item, that
limit is exceeded, the oldest item is sent to landfill. THe limits are encoded in a new global variable, maximum-in-category-table, which is read in by read-table2 from maximum-
in-category-file. It is a two-level table, with keys on the outer level identifying household types, those on the inner level identifying categories of appliance. There is a place on the interface for the identity of the file.
* Changed update-wish-list and added a new global variable, new-subcategory-appliances-per-step, for which there is a slider on the interface, to
allow the maximum number of new subcategory appliances to be added to the wish-list to be set as a parameter.

2011-10-03 Nick Gotts
* Changed gain-insulation local variable name current-projected-heating-cost to current-projected-space-heating-cost for consistency.

2011-10-02 Nick Gotts
* Made changes to allow specification of the appliances individual households own at the start of a run, in the households file (as well as or instead of allocating specific items to all households using the appliances file). The code changes affect setup (the order of calls to setup-appliances and setup-households is reversed, so they now appear in that order), setup-households, read-households-file (which includes the only substantive new code, to read the variable number of extra columns that may be found in the households file, giving the names and ages of appliances that household owns) and setup-appliances (some lines of which are transferred to setup-households). These rearrangements are necessary ensure stages of the setup process happen in the right order.

2011-09-28 Nick Gotts
* Amended procedure calculate-moeu so that the correction for insulation is only applied to heating-system costs for (space) heating, not for hot water. Changed the name of purpose "heating" to "space-heating" in calculate-moeu, calculate-current-running-cost and gain-insulation, to avoid confusion with the appliance category "heating".

2011-09-27 Nick Gotts
* Added code for the procedure norm-insulation, which implements household decisions on
whether to buy an insulation upgrade when in norm mode (and if so, which of the possible upgrades).
* Amended procedure calculate-current-running-cost so that the correction for insulation is only applied to heating-saystem costs for (space) heating, not for hot water.

2011-09-26 Nick Gotts
* Added code for the procedures calculate-projected-heating-cost-over-planning-horizon and calculate-current-heating-cost, required to make gain-insulation work. Removed dummy procedures accessible-insulation-states and calculate-expected-heating-costs-over-planning-horizon.

2011-09-25 Nick Gotts
* Amended code for the procedure gain-insulation.

2011-09-21 Nick Gotts
* Added conditionals and an extra button, use-social-links, to make the use of social links optional.
* Removed a spurious "u" from "neighbours" in step, just preceding the call to buy-insulation.
* Added code for the procedure gain-insulation, which implements household decisions on
whether to buy an insulation upgrade when in gain mode (and if so, which of the possible upgrades). Dummy procedures accessible-insulation-states and calculate-expected-heating-costs-over-planning-horizon, called from gain-insulation, also added.

2011-09-14 Nick Gotts for Gary Polhill
* Added dummy procedures gain-insulation and norm-insulation, procedure buy-insulation which calls them, and a call to this from step, with a condition that the household's dwelling is owned not rented.

2011-09-14 Gary Polhill
* Created steps-per-year parameter and adjusted code in calculate-moeu and setup-globals to use that. Changed names of parameters and variables containing 'month' to say 'step' instead.
* Removed random perturbations of dwellings on patches. Instead the patch colour brightens by 1 for each dwelling located on it after the first, until the colour has a 9 in the last digit.
* Added tenure to dwelling breed, and changed relevant file formats accordingly. Updated resample-parameters, setup-households and calculate-moeu to use tenure.
* Changed replace-broken-appliances to take account of heating appliances and tenure. Added calculate-current-running-cost (which could not be extracted from calculate-moeu as the latter also totals the actual fuel used) and calculate-projected-running-cost, used by heating-system-cost-advice.

2011-05-23 Gary Polhill
* Extracted buy-new-appliances from step
* Amended hedonistic-equip, norm-equip and gain-equip to buy new appliances in accordance with email exchange and meeting between Nick Gotts and Gary Polhill on 16 May 2011.
* Added land-fill list
* Added plots of land fill, goal frame and goal frame parameters
* Fixed bug in choose-goal-frame owing to not being aware that random-float binds more tightly than +
* Modified current-replacements-... procedures to use last-month-available-unbounded
* Removed shopping-probability parameter
* Added visits per link plot

2011-05-20 Gary Polhill
* Changed fuel consumption ontology to have a consumption agent as an intermediary between appliances and fuel
* Added appliances plot showing number of ownership relations
* Added colour for plotting energy use by fuel-type
* Added age of ownership relation
* Added new-category-months, old-product-months and visits-per-month sliders
* Computed new-subcategories in update-globals
* Extracted procedure replace-broken-equipment from step
* Created update-wish-list

2011-05-16 Gary Polhill
* Updated block-id setting algorithm to fix bug for wrapped spaces
* Fixed bug during setup causing warning message
* Set household and dwelling colour and shape displays
* Updated calculate-moeu to use the new ontology

2011-05-10 Gary Polhill
* Created an output window and directed all error and warning messages to it.
* Added use-household-file switch
* Changed choose-goal-frame so it just makes a selection in the range [0, hedonism + gain-orientation + greenness]
* Changed value-adjust so it keeps the goal frames independent
* Removed the rfloat global variable

2011-05-09 Gary Polhill
* Made frame-adjustment, planning-horizon and choose (now "shopping-probability") household parameters rather than global variables, and adjusted household initialisation, parameter resampling and CSV file reading procedures accordingly.
* Modified setup-households to create households using in-migrant file parameters for dwellings that are unoccupied after loading in the household file.
* Modified make-social-links to check that there is not already a link to the household.
* Did the same for make-patch-social-links, make-radius-social-links and make-patch-type-social-links.
* Updated read-appliances-fuel-use to have the units used for each month in separate columns of the same row (rather than earlier format of one row per month)
* Updated transition-household-state and read-numeric-ts-matrix to have in-migrant column.
* Wrote read-appliance-similarity and documentation.
* Rearranged the interface so the number of patches can be increased without overlapping other widgets.

2011-05-04 Gary Polhill
* Added procedure to read fuel suppliers
* Added procedures to set up households, appliances, energy and patches (these are significant revisions of earlier setup* procedures
* Modified setup-files to query the user for all 15 files

2011-05-03 Gary Polhill
* Added documentation on various input files
* Added procedure to read in fuel consumption per appliance use context with wildcards

2011-04-30 Gary Polhill
* Added functionality to use the usage-mode information

2011-04-26 Gary Polhill
* Added procedure to read in in-migrant household parameters

2011-04-25 Gary Polhill
* Added procedure to read in household parameters

2011-04-21 Gary Polhill
* Code tidy and commenting
* Documentation

2011-04-20 Gary Polhill
* Separated households and dwellings
* Changed patch file format to CSV
* Added procedures to read from a CSV file
* Added household state transitions

2010-12-08 Gary Polhill
* Added read-appliances procedure to load appliances in from an appliance file
* Added write-appliances procedure to save appliances to an appliance file
* Added assign-replacements procedure to assign appliances' replacement links from a table
* Added read-text procedure to read some specific text from a file
* Extracted read-equipment from setup-globals
* Extracted read-equipment-similarity from setup-globals
* Extracted read-energy-price from setup-globals
* Started code tidy and commenting
* Started replacing equipment with appliance agents
* Added GNU General Public Licence

2010-12-07 Gary Polhill
* Added appliance agent and link agents for ownership of appliances, replacement of appliances, similarity of appliances, and social links between households.
* Added create-an-example-equipment file procedure to build an appliance agentset from the loaded list of equipment, and save it to a file
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

house bungalow
false
0
Rectangle -7500403 true true 210 75 225 255
Rectangle -7500403 true true 90 135 210 255
Rectangle -16777216 true false 165 195 195 255
Line -16777216 false 210 135 210 255
Rectangle -16777216 true false 105 202 135 240
Polygon -7500403 true true 225 150 75 150 150 75
Line -16777216 false 75 150 225 150
Line -16777216 false 195 120 225 150
Polygon -16777216 false false 165 195 150 195 180 165 210 195
Rectangle -16777216 true false 135 105 165 135

house colonial
false
0
Rectangle -7500403 true true 270 75 285 255
Rectangle -7500403 true true 45 135 270 255
Rectangle -16777216 true false 124 195 187 256
Rectangle -16777216 true false 60 195 105 240
Rectangle -16777216 true false 60 150 105 180
Rectangle -16777216 true false 210 150 255 180
Line -16777216 false 270 135 270 255
Polygon -7500403 true true 30 135 285 135 240 90 75 90
Line -16777216 false 30 135 285 135
Line -16777216 false 255 105 285 135
Line -7500403 true 154 195 154 255
Rectangle -16777216 true false 210 195 255 240
Rectangle -16777216 true false 135 150 180 180

house efficiency
false
0
Rectangle -7500403 true true 180 90 195 195
Rectangle -7500403 true true 90 165 210 255
Rectangle -16777216 true false 165 195 195 255
Rectangle -16777216 true false 105 202 135 240
Polygon -7500403 true true 225 165 75 165 150 90
Line -16777216 false 75 165 225 165

house ranch
false
0
Rectangle -7500403 true true 270 120 285 255
Rectangle -7500403 true true 15 180 270 255
Polygon -7500403 true true 0 180 300 180 240 135 60 135 0 180
Rectangle -16777216 true false 120 195 180 255
Line -7500403 true 150 195 150 255
Rectangle -16777216 true false 45 195 105 240
Rectangle -16777216 true false 195 195 255 240
Line -7500403 true 75 195 75 240
Line -7500403 true 225 195 225 240
Line -16777216 false 270 180 270 255
Line -16777216 false 0 180 300 180

house two story
false
0
Polygon -7500403 true true 2 180 227 180 152 150 32 150
Rectangle -7500403 true true 270 75 285 255
Rectangle -7500403 true true 75 135 270 255
Rectangle -16777216 true false 124 195 187 256
Rectangle -16777216 true false 210 195 255 240
Rectangle -16777216 true false 90 150 135 180
Rectangle -16777216 true false 210 150 255 180
Line -16777216 false 270 135 270 255
Rectangle -7500403 true true 15 180 75 255
Polygon -7500403 true true 60 135 285 135 240 90 105 90
Line -16777216 false 75 135 75 180
Rectangle -16777216 true false 30 195 93 240
Line -16777216 false 60 135 285 135
Line -16777216 false 255 105 285 135
Line -16777216 false 0 180 75 180
Line -7500403 true 60 195 60 240
Line -7500403 true 154 195 154 255

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.2.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="BS1-1" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>months-all-household-total-energy-use</metric>
    <metric>all-household-capital-reserves</metric>
    <metric>count links</metric>
    <enumeratedValueSet variable="economising-fraction">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-change-index">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="halt-after">
      <value value="144"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-gain-orientation">
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-income">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="credit-multiple-limit">
      <value value="0"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reciprocal-adjustment">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="choose">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-greenness">
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-hedonism">
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="frame-adjustment">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planning-horizon">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-links">
      <value value="15"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="BS1-4" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>months-all-household-total-energy-use</metric>
    <metric>all-household-capital-reserves</metric>
    <metric>count links</metric>
    <enumeratedValueSet variable="economising-fraction">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-change-index">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="halt-after">
      <value value="144"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-gain-orientation">
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-income">
      <value value="100"/>
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="credit-multiple-limit">
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reciprocal-adjustment">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="choose">
      <value value="0.1"/>
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-greenness">
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-hedonism">
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="frame-adjustment">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planning-horizon">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-links">
      <value value="15"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="BS1-3" repetitions="2" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>months-all-household-total-energy-use</metric>
    <metric>all-household-capital-reserves</metric>
    <metric>count links</metric>
    <enumeratedValueSet variable="choose">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="credit-multiple-limit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-income">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="frame-adjustment">
      <value value="0"/>
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-gain-orientation">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-links">
      <value value="15"/>
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="halt-after">
      <value value="144"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="economising-fraction">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-hedonism">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planning-horizon">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-greenness">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reciprocal-adjustment">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-change-index">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="BS1c-1" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>months-all-household-total-energy-use</metric>
    <metric>all-household-capital-reserves</metric>
    <metric>count links</metric>
    <enumeratedValueSet variable="economising-fraction">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-change-index">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="halt-after">
      <value value="144"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-gain-orientation">
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-income">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="credit-multiple-limit">
      <value value="0"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reciprocal-adjustment">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="choose">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-greenness">
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-hedonism">
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="frame-adjustment">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planning-horizon">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-links">
      <value value="15"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="BS1c-2" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>months-all-household-total-energy-use</metric>
    <metric>all-household-capital-reserves</metric>
    <metric>count links</metric>
    <enumeratedValueSet variable="min-hedonism">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="credit-multiple-limit">
      <value value="0"/>
      <value value="5"/>
      <value value="10"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reciprocal-adjustment">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-change-index">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="choose">
      <value value="0.1"/>
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planning-horizon">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-links">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="economising-fraction">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-income">
      <value value="100"/>
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-greenness">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="halt-after">
      <value value="144"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="frame-adjustment">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-gain-orientation">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="BS1c-1-0.8" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>months-all-household-total-energy-use</metric>
    <metric>all-household-capital-reserves</metric>
    <metric>count links</metric>
    <enumeratedValueSet variable="economising-fraction">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-change-index">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="halt-after">
      <value value="144"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-gain-orientation">
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-income">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="credit-multiple-limit">
      <value value="0"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reciprocal-adjustment">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="choose">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-greenness">
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-hedonism">
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="frame-adjustment">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planning-horizon">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-links">
      <value value="15"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="BS1c-1-true" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>months-all-household-total-energy-use</metric>
    <metric>all-household-capital-reserves</metric>
    <metric>count links</metric>
    <enumeratedValueSet variable="economising-fraction">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-change-index">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="halt-after">
      <value value="144"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-gain-orientation">
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-income">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="credit-multiple-limit">
      <value value="0"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reciprocal-adjustment">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="choose">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-greenness">
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-hedonism">
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="frame-adjustment">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planning-horizon">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-links">
      <value value="15"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="BS1c-1-true-0.4" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>months-all-household-total-energy-use</metric>
    <metric>all-household-capital-reserves</metric>
    <metric>count links</metric>
    <enumeratedValueSet variable="economising-fraction">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-change-index">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="halt-after">
      <value value="144"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-gain-orientation">
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-income">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="credit-multiple-limit">
      <value value="0"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reciprocal-adjustment">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="choose">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-greenness">
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-hedonism">
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="frame-adjustment">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planning-horizon">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-links">
      <value value="15"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="BS1c-1-0" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>months-all-household-total-energy-use</metric>
    <metric>all-household-capital-reserves</metric>
    <metric>count links</metric>
    <enumeratedValueSet variable="economising-fraction">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-change-index">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="halt-after">
      <value value="144"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-gain-orientation">
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-income">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="credit-multiple-limit">
      <value value="0"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reciprocal-adjustment">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="choose">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-greenness">
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-hedonism">
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="frame-adjustment">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planning-horizon">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-links">
      <value value="15"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="BS1c-2-0" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>months-all-household-total-energy-use</metric>
    <metric>all-household-capital-reserves</metric>
    <metric>count links</metric>
    <enumeratedValueSet variable="min-hedonism">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="credit-multiple-limit">
      <value value="0"/>
      <value value="5"/>
      <value value="10"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reciprocal-adjustment">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-change-index">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="choose">
      <value value="0.1"/>
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planning-horizon">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-links">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="economising-fraction">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-income">
      <value value="100"/>
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-greenness">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="halt-after">
      <value value="144"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="frame-adjustment">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-gain-orientation">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="BS1c-2-0.4" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>months-all-household-total-energy-use</metric>
    <metric>all-household-capital-reserves</metric>
    <metric>count links</metric>
    <enumeratedValueSet variable="min-hedonism">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="credit-multiple-limit">
      <value value="0"/>
      <value value="5"/>
      <value value="10"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reciprocal-adjustment">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-change-index">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="choose">
      <value value="0.1"/>
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planning-horizon">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-links">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="economising-fraction">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-income">
      <value value="100"/>
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-greenness">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="halt-after">
      <value value="144"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="frame-adjustment">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-gain-orientation">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="BS1c-2-true" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>months-all-household-total-energy-use</metric>
    <metric>all-household-capital-reserves</metric>
    <metric>count links</metric>
    <enumeratedValueSet variable="min-hedonism">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="credit-multiple-limit">
      <value value="0"/>
      <value value="5"/>
      <value value="10"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reciprocal-adjustment">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-change-index">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="choose">
      <value value="0.1"/>
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planning-horizon">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-links">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="economising-fraction">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-income">
      <value value="100"/>
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-greenness">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="halt-after">
      <value value="144"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="frame-adjustment">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-gain-orientation">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="BS1c-20100914-1" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>months-all-household-total-energy-use</metric>
    <metric>all-household-capital-reserves</metric>
    <metric>count links</metric>
    <enumeratedValueSet variable="economising-fraction">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-change-index">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="halt-after">
      <value value="144"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-gain-orientation">
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-income">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="credit-multiple-limit">
      <value value="0"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reciprocal-adjustment">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="choose">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-greenness">
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-hedonism">
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="frame-adjustment">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planning-horizon">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-links">
      <value value="15"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="abmed-BS1c-1-0.2-0.5-0.8" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>months-all-household-total-energy-use</metric>
    <metric>all-household-capital-reserves</metric>
    <metric>count links</metric>
    <enumeratedValueSet variable="economising-fraction">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-change-index">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="halt-after">
      <value value="144"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-gain-orientation">
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-income">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="credit-multiple-limit">
      <value value="0"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reciprocal-adjustment">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="choose">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-greenness">
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-hedonism">
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="frame-adjustment">
      <value value="0.2"/>
      <value value="0.5"/>
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planning-horizon">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-links">
      <value value="15"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="profiler" repetitions="10" runMetricsEveryStep="false">
    <setup>profiler:start
setup</setup>
    <go>go</go>
    <final>profiler:stop
profiler:reset</final>
    <timeLimit steps="144"/>
    <metric>profile-setup</metric>
    <metric>profile-go</metric>
    <enumeratedValueSet variable="frame-adjustment">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-pxcor">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-pycor">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-file">
      <value value="&quot;block-square-patch-10x10-9-1.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="economising-fraction">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-hedonism">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="equipment-similarity-file">
      <value value="&quot;cedss-0-trials-similarity-a.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="halt-after">
      <value value="197"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-gain-orientation">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-link-file">
      <value value="&quot;block-square-link-9-1-0.5-0.1.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="credit-multiple-limit">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="equipment-file">
      <value value="&quot;equipment-test2.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-change-index">
      <value value="13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="energy-price-file">
      <value value="&quot;cedss-0-trials-energy-prices-a.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-greenness">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reciprocal-adjustment">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planning-horizon">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="choose">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-income">
      <value value="3300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-links">
      <value value="15"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
