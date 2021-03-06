globals
[
  num-patches-t        ;; total number of patches on the map
  area-t               ;; total area in kilometers of the map. One patch is 6.67m by 6.67m
  density              ;; number of patches per square kilometer. sparse = 1, dense = 32
  num-patches-r        ;; number of desired resource patches on the map
  resource-prob        ;;
  resource-prob-adj    ;; resource-prob adjusted for patchiness. Total probability for each square for each patchiness iteration

  patches-with-resource?  ;; agentset of patches with resource? = True
  fd-amt                  ;; number of patches that bees move each tick
  nectar-influx-colony    ;; total energy collected/simulation duration/colony size

  c0       ;; probability of resource with no resource within 2 spaces
  c1       ;; probability of resource with at least one resource one patch away
  c2       ;; probability of resource with at least one resource two patches away
  c0-num   ;; 1 / (c0). 1 in resource-prob-num chances c0 patch is a resource
  c1-num   ;; 1 / (c1). 1 in resource-prob-num chances c1 patch is a resource
  c2-num   ;; 1 / (c2). 1 in resource-prob-num chances c2 patch is a resource

  c1-mult    ;; patch probability multiplier for c1 patches
  c2-mult    ;; patch probability multiplier for c2 patches
             ;patchiness ;; number of iterations when assigning patches
  R-exp      ;; expected value of R
  loop-num   ;; number of times environment have to be generated to get environment R-R_exp <= 0.3

  Ra
  Re
  R
  end-setup
]
turtles-own
[
  collected            ;; amount of food collected by each bee
  energy               ;; bee energy level
  state                ;; state bee is in
  next-state           ;; State to transition to at the end of the time step.
                       ;; states: inactive = Inactive, toResource = Direct to Resource, randSearch = Random Search,
                       ;;         forage = Forage at Resource, return = Return to Hive, dance = Dancing
                       ; variables specific to some states
  time-foraging        ;; if bee is foraging, time bee has spent foraging on current foraging trip (else 0)
  mem-resource-patch   ;; patch remembered by returning bee
  patch-to-go-to       ;; patch that bee was recruited to go to (if any)
]
patches-own
[
  nest?                ;; true on nest patches
  resource?            ;; true on resource patches
  resource-new?        ;; true on resource patches before setup-resource-surrounding
  quantity             ;; amount of food per patch
  quality              ;; quality of resource
  ephemeral            ;; value to determine if resource disappears
  food-wasted          ;; wasted food of ephemeral resource that disappears

  c0?  ;; no resources within 2 patches
  c1?  ;; at least one resource one patch away
  c2?  ;; not c1 and at least one resource two patches away
  c-parent ;; 'parent' (resource) patch for c1 and c2 patches
]

;;;;;;;;;;;;;;;;;;;;;;;;
;;; Setup procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  reset-timer
  reset-ticks
  error-check
  show "Start"
  set-default-shape turtles "bee"
  crt population
  [
    set size 2
    set color yellow
  ]
  setup-turtles
  setup-patches
  set end-setup 1
  set fd-amt 1   ;; fd 15 on big map: 25 km/h = 6.9 m/s = 15 patches/tick
end

to error-check ;; error checks on user input

end

to setup-turtles
  ask turtles
  [
    set state "inactive"
    set next-state ""
    if bee_label?
    [
      set label-color black
      set label state
    ]
  ]
end

to setup-patches
  ;R-parameters
  set c1-mult c1_mult
  set c2-mult c2_mult
  resource-patch-calculations
  set loop-num 0

  ;while [(abs(R-exp - R) > 0.03) and (loop-num <= 10)]
  ;[
  ;set loop-num loop-num + 1
  ;show (word "new loop: " loop-num)
  ask patches [ setup-patch-initial ]
  repeat patchiness
    [
      c1-c2-calculations
      ask patches with [not nest? and not resource?] [ setup-resource-choose ]
      ask patches with [resource-new?]               [ setup-resource-c1c2 ]
    ]

  set patches-with-resource? patches with [resource?]

  R-calc
  show R
  ;]
end

to resource-patch-calculations ;; Calculations to determine probability each patch is a resource
  set num-patches-t       world-width * world-height - 1 ;for nest patch
  set area-t              num-patches-t * .000044444
  if resource_density =   "extra_sparse" [ set density 0.4 ]
  if resource_density =   "sparse" [ set density 1 ]
  if resource_density =   "dense" [ set density 32 ]
  set num-patches-r       area-t * density
  set resource-prob       num-patches-r / num-patches-t
  set resource-prob-adj   resource-prob / patchiness
end

to setup-patch-initial ;; create hive patch and initialize all other patches
  ifelse (distancexy 0 0) < 1
  [ ; hive
    set pcolor brown
    set nest? True
    set c0? False
  ]
  [ ; non-hive
    set pcolor gray ; non-hive
    set nest? False
    set c0? True
  ]
  ; all
  set plabel ""
  set resource? False
  set resource-new? False
  set c1? False
  set c2? False
  set c-parent 0
end

to c1-c2-calculations
  let c0-count count patches with [c0?]
  let c1-count count patches with [c1?]
  let c2-count count patches with [c2?]
  let p0 (c0-count) / num-patches-t
  let p1 (c1-count) / num-patches-t
  let p2 (c2-count) / num-patches-t

  set c0 resource-prob-adj / (p0 + c1-mult * p1 + c2-mult * p2)
  ifelse (c1-count = 0) [set c1 0] [set c1 c1-mult * c0]
  ifelse (c2-count = 0) [set c2 0] [set c2 c2-mult * c0]

  set c0-num 1 / c0
  ifelse (c2-count = 0) [set c1-num 0] [set c1-num 1 / c1]
  ifelse (c2-count = 0) [set c2-num 0] [set c2-num 1 / c2]
end

to setup-resource-choose  ;; assign new food patches, including quantity and quality.
  let c1-2-select FALSE
  let c0-select FALSE

  ifelse ((c1-num != 0 and c1? and random c1-num < 1) or (c2-num != 0 and c2? and random c2-num < 1))
  [ set c1-2-select TRUE ]
  [ if (c0? and random c0-num < 1) [ set c0-select TRUE ] ]
  if (c1-2-select or c0-select)
  [
    set pcolor green
    set resource-new? True
    set c0? False
    set c1? False
    set c2? False

    ; Resource quality
    ifelse quality_distrib
    [
      ifelse (c1-2-select)
      [ set quality [quality] of c-parent ]
      [ set quality random-poisson quality_mean ]
    ]
    [ set quality quality_mean ]
    ; Resource quantity
    set quantity 100 ; 100 trips to this flower

                     ; Resource label, if necessary
    if quality_label?  [ set plabel quality ]
    if quantity_label? [ set plabel quantity ]
  ]
end

to setup-resource-c1c2  ;; set appropriate patch variables for patches around new resource
  set resource-new? False
  set resource? True
  ask neighbors
  [
    if (not nest? and not resource? and not resource-new?)
    [
      set c0? False
      set c1? True
      set c2? False
      set c-parent myself
    ]
    ask neighbors
    [
      if (not nest? and not resource? and not resource-new? and not c1? and not c2?)
      [
        set c0? False
        set c2? True
        set c-parent [c-parent] of myself
      ]
    ]
  ]
end

to R-calc ;; Calculate R spatial value
  if ((count patches-with-resource? = 0) or (count patches-with-resource? = 1))
  [ user-message "Must have more than one resource to calculate R" stop ]

  let list-dist []
  ask patches-with-resource?
  [
    let dist distance min-one-of other patches-with-resource? [distance myself]
    set dist dist * .0066667
    set list-dist lput dist list-dist

  ]
  ;show sort list-dist
  set Ra mean list-dist
  set Re 1 / (2 * sqrt density)
  set R Ra / Re
end


;;;;;;;;;;;;;;;;;;;;;
;;; Go procedures ;;;
;;;;;;;;;;;;;;;;;;;;;

to go  ;; forever button
  ask turtles
  [ ;if who >= ticks [ stop ] ;; delay initial departure
    ;; Actions based on states
    if state = "inactive"
    [ inactive ]
    if state = "toResource"
    [  ]
    if state = "randSearch"
    [ random-search ]
    if state = "forage"
    [ forage-nectar ]
    if state = "return"
    [ return-to-hive ]
    if state = "dance"
    [  ]

    ; Update states
    transition
  ]
  if ephemeral? = True
    [ ask patches
      [ if resource?
        [ if random 10000 < 10 ;; TODO: ephemeral resources
          [ remove-patch ]
        ]
      ]
    ]
  tick
end

to transition
  if next-state != ""
  [ set state next-state
    set next-state "" ]
end

to inactive
  ;; transition to randSearch
  if random 1000 <= 33 ; actual map: 100000 -> 0.00033/tick ;; TODO: Adjust to actual values
  [ set next-state "randSearch" ]
  ;; TODO: transition to toResource
  ;; action-at end because stop ends all
  stop
end

to random-search
  ifelse (resource? = True)
  [
    set next-state "forage"
    stop
  ]
  [
    let closest min-one-of patches-with-resource? [distance turtle 0]
    ifelse ((distance closest) < (25 / 6.67))
    [
      move-to closest
      set next-state "forage"
      stop
    ]
    [
      wiggle
      fd fd-amt * 0.2
    ]
  ]
end

to wiggle
  lt (90 - random 180)
  if not can-move? (fd-amt * 0.2) [ rt 180 ]
end

to forage-nectar
  set color pink
  set time-foraging time-foraging + 1
  if (time-foraging = 48) ; 15 sec/tick -> 12 minutes is 48 ticks
  [
    set collected collected + quality
    set mem-resource-patch patch-here
    set next-state "return"

    ;; Update patch
    set quantity quantity - 1
    if quantity_label?
    [
      set plabel quantity
      if quantity = 0
      [
        set pcolor white
        set plabel ""
      ]
    ]
  ]
end

to return-to-hive
  ifelse nest?
  [
    set color yellow
    ; add nectar-influx-colony?
    ifelse communication?  ;; TODO: dancing vs inactive
    [
      ; e-res = net energy gained/energy expended
      let e-res collected ;; TODO: fix
      let p-recruit .016 * e-res / nectar-influx-colony
      let p-recruit-num (1 / p-recruit)
      ifelse (random p-recruit-num < 1)
      [ set next-state "dance" ]
      [ set next-state "inactive" ]
    ]
    [ set next-state "inactive" ]
  ]
  [
    facexy 0 0
    fd fd-amt
  ]
end

to dance
  ;ask one-of turtles with [state = "inactive"]
  ;[
  ;  set patch-to-go-to mem-resource-patch
  ;  set next-state "toResource"
  ;]
end

to remove-patch
  set food-wasted quantity * quality
  set quantity 0
  set pcolor pink
  set plabel ""
  set resource? False
end
@#$#@#$#@
GRAPHICS-WINDOW
336
10
1847
1542
750
750
1.0
1
10
1
1
1
0
0
0
1
-750
750
-750
750
1
1
1
ticks
30.0

BUTTON
231
36
311
69
NIL
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
231
72
306
105
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
31
36
221
69
population
population
0.0
20
5
1
1
NIL
HORIZONTAL

PLOT
8
548
251
827
Food remaing and collected
time
food
0.0
50.0
0.0
120.0
true
false
"" ""
PENS
"remaining" 1.0 0 -13840069 true "" "plotxy ticks sum [quantity] of patches"
"collected" 1.0 0 -2674135 true "" "plotxy ticks sum [collected] of turtles"
"wasted" 1.0 0 -7500403 true "" "if ephemeral? [plotxy ticks sum [food-wasted] of patches]"

SWITCH
31
410
158
443
bee_label?
bee_label?
1
1
-1000

SLIDER
31
254
158
287
quality_mean
quality_mean
0
40
25
1
1
NIL
HORIZONTAL

SWITCH
166
370
306
403
quality_label?
quality_label?
0
1
-1000

SWITCH
31
370
158
403
ephemeral?
ephemeral?
1
1
-1000

CHOOSER
32
111
170
156
resource_density
resource_density
"extra_sparse" "sparse" "dense"
1

MONITOR
217
128
285
173
NIL
R
5
1
11

SWITCH
172
254
318
287
quality_distrib
quality_distrib
0
1
-1000

SWITCH
166
410
315
443
quantity_label?
quantity_label?
1
1
-1000

SWITCH
32
72
190
105
communication?
communication?
0
1
-1000

CHOOSER
32
157
170
202
R_value
R_value
"0.4" "0.6" "0.8" "1.0"
0

SLIDER
49
307
221
340
c1_mult
c1_mult
1
1501
1501
1
1
NIL
HORIZONTAL

SLIDER
123
335
295
368
c2_mult
c2_mult
1
1501
1201
1
1
NIL
HORIZONTAL

SLIDER
52
214
224
247
patchiness
patchiness
1
21
1
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?


## HOW IT WORKS



## HOW TO USE IT



## THINGS TO NOTICE


## EXTENDING THE MODEL


## NETLOGO FEATURES
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

bee
true
0
Polygon -1184463 true false 152 149 77 163 67 195 67 211 74 234 85 252 100 264 116 276 134 286 151 300 167 285 182 278 206 260 220 242 226 218 226 195 222 166
Polygon -16777216 true false 150 149 128 151 114 151 98 145 80 122 80 103 81 83 95 67 117 58 141 54 151 53 177 55 195 66 207 82 211 94 211 116 204 139 189 149 171 152
Polygon -7500403 true true 151 54 119 59 96 60 81 50 78 39 87 25 103 18 115 23 121 13 150 1 180 14 189 23 197 17 210 19 222 30 222 44 212 57 192 58
Polygon -16777216 true false 70 185 74 171 223 172 224 186
Polygon -16777216 true false 67 211 71 226 224 226 225 211 67 211
Polygon -16777216 true false 91 257 106 269 195 269 211 255
Line -1 false 144 100 70 87
Line -1 false 70 87 45 87
Line -1 false 45 86 26 97
Line -1 false 26 96 22 115
Line -1 false 22 115 25 130
Line -1 false 26 131 37 141
Line -1 false 37 141 55 144
Line -1 false 55 143 143 101
Line -1 false 141 100 227 138
Line -1 false 227 138 241 137
Line -1 false 241 137 249 129
Line -1 false 249 129 254 110
Line -1 false 253 108 248 97
Line -1 false 249 95 235 82
Line -1 false 235 82 144 100

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
NetLogo 5.3
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="time" repetitions="1" runMetricsEveryStep="false">
    <setup>setup
reset-timer</setup>
    <go>go</go>
    <exitCondition>ticks = 100</exitCondition>
    <metric>timer</metric>
    <steppedValueSet variable="population" first="500" step="2000" last="9500"/>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="world-width">
      <value value="1001"/>
      <value value="2001"/>
      <value value="3001"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="world-height">
      <value value="1001"/>
      <value value="2001"/>
      <value value="3001"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="setup-time" repetitions="2" runMetricsEveryStep="true">
    <setup>reset-timer
setup</setup>
    <go>go</go>
    <timeLimit steps="1"/>
    <exitCondition>ticks = 1</exitCondition>
    <metric>timer</metric>
    <enumeratedValueSet variable="min-pxcor">
      <value value="-1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-pxcor">
      <value value="1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-pycor">
      <value value="-1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-pycor">
      <value value="1500"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="R testing" repetitions="1" runMetricsEveryStep="false">
    <setup>set-patch-size 1
resize-world -500 500 -500 500
reset-timer
setup</setup>
    <go>go</go>
    <exitCondition>ticks = 1</exitCondition>
    <metric>R</metric>
    <metric>timer</metric>
    <steppedValueSet variable="c1_mult" first="1" step="40" last="201"/>
    <steppedValueSet variable="c2_mult" first="1" step="40" last="201"/>
    <steppedValueSet variable="patchiness" first="1" step="4" last="21"/>
    <enumeratedValueSet variable="resource_density">
      <value value="&quot;sparse&quot;"/>
      <value value="&quot;dense&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calc_R">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="resource_nums" repetitions="20" runMetricsEveryStep="false">
    <setup>set-patch-size 1
resize-world -500 500 -500 500
setup</setup>
    <go>go</go>
    <exitCondition>ticks = 1</exitCondition>
    <metric>num-patches-r</metric>
    <metric>count patches with [resource?]</metric>
    <enumeratedValueSet variable="resource_density">
      <value value="&quot;sparse&quot;"/>
      <value value="&quot;dense&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="patchiness" first="1" step="4" last="21"/>
    <steppedValueSet variable="c1_mult" first="1" step="40" last="201"/>
    <steppedValueSet variable="c2_mult" first="1" step="40" last="201"/>
    <enumeratedValueSet variable="calc_R">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="resource_nums_test" repetitions="1" runMetricsEveryStep="false">
    <setup>set-patch-size 1
resize-world -50 50 -50 50
setup</setup>
    <go>go</go>
    <timeLimit steps="1"/>
    <exitCondition>("c2_mult" &gt; "c1_mult") or (ticks = 1)</exitCondition>
    <metric>num-patches-r</metric>
    <metric>count patches with [resource?]</metric>
    <enumeratedValueSet variable="resource_density">
      <value value="&quot;sparse&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patchiness">
      <value value="1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="c2_mult" first="1" step="40" last="201"/>
    <steppedValueSet variable="c1_mult" first="1" step="40" last="201"/>
    <enumeratedValueSet variable="calc_R">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="R value testing" repetitions="10" runMetricsEveryStep="false">
    <setup>set-patch-size 1
resize-world -500 500 -500 500
reset-timer
setup</setup>
    <go>go</go>
    <exitCondition>ticks = 1</exitCondition>
    <metric>R</metric>
    <metric>timer</metric>
    <enumeratedValueSet variable="c1_mult">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="c2_mult">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patchiness">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="resource_density">
      <value value="&quot;sparse&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calc_R">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="R sparse testing" repetitions="4" runMetricsEveryStep="false">
    <setup>reset-timer
setup</setup>
    <go>go</go>
    <exitCondition>end-setup = 1</exitCondition>
    <metric>R</metric>
    <metric>timer</metric>
    <steppedValueSet variable="c1_mult" first="1501" step="300" last="2101"/>
    <steppedValueSet variable="c2_mult" first="1" step="300" last="2101"/>
    <steppedValueSet variable="patchiness" first="1" step="4" last="25"/>
    <enumeratedValueSet variable="resource_density">
      <value value="&quot;sparse&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-pxcor">
      <value value="-1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-pxcor">
      <value value="1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-pycor">
      <value value="-1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-pycor">
      <value value="1500"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="R dense testing" repetitions="20" runMetricsEveryStep="false">
    <setup>set-patch-size 1
resize-world -500 500 -500 500
reset-timer
setup</setup>
    <go>go</go>
    <exitCondition>ticks = 1</exitCondition>
    <metric>R</metric>
    <metric>timer</metric>
    <steppedValueSet variable="c1_mult" first="1" step="40" last="201"/>
    <steppedValueSet variable="c2_mult" first="1" step="40" last="201"/>
    <steppedValueSet variable="patchiness" first="1" step="4" last="21"/>
    <enumeratedValueSet variable="resource_density">
      <value value="&quot;dense&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calc_R">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="R trials" repetitions="10" runMetricsEveryStep="false">
    <setup>set-patch-size 1
resize-world -1500 1500 -1500 1500
reset-timer
setup</setup>
    <go>go</go>
    <timeLimit steps="1"/>
    <exitCondition>end-setup = 1</exitCondition>
    <metric>R</metric>
    <metric>loop-num</metric>
    <metric>timer</metric>
    <enumeratedValueSet variable="resource_density">
      <value value="&quot;sparse&quot;"/>
      <value value="&quot;dense&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R_value">
      <value value="&quot;0.4&quot;"/>
      <value value="&quot;0.6&quot;"/>
      <value value="&quot;0.8&quot;"/>
      <value value="&quot;1.0&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="R extra_sparse testing" repetitions="7" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>end-setup = 1</exitCondition>
    <metric>R</metric>
    <metric>timer</metric>
    <steppedValueSet variable="c1_mult" first="1501" step="300" last="2401"/>
    <steppedValueSet variable="c2_mult" first="1201" step="300" last="2101"/>
    <steppedValueSet variable="patchiness" first="1" step="4" last="21"/>
    <enumeratedValueSet variable="resource_density">
      <value value="&quot;extra_sparse&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calc_R">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-pxcor">
      <value value="-750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-pxcor">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-pycor">
      <value value="-750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-pycor">
      <value value="750"/>
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
