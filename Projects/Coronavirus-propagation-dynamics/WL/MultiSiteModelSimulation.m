(*
    Multi-site model simulation Mathematica package
    Copyright (C) 2020  Anton Antonov

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

    Written by Anton Antonov,
    antononcube @ gmail . com,
    Windermere, Florida, USA.
*)

(*
    Mathematica is (C) Copyright 1988-2020 Wolfram Research, Inc.

    Protected by copyright law and international treaties.

    Unauthorized reproduction or distribution subject to severe civil
    and criminal penalties.

    Mathematica is a registered trademark of Wolfram Research, Inc.
*)


(* :Title: MutliSiteModelSimulation *)
(* :Context: Global` *)
(* :Author: Anton Antonov *)
(* :Date: 2020-04-01 *)

(* :Package Version: 0.1 *)
(* :Mathematica Version: 12.1 *)
(* :Copyright: (c) 2020 Anton Antonov *)
(* :Keywords: *)
(* :Discussion: *)


(**************************************************************)
(* Importing packages (if needed)                             *)
(**************************************************************)

If[Length[DownValues[EpidemiologyModels`SIRModel]] == 0,
  Echo["EpidemiologyModels.m", "Importing from GitHub:"];
  Import["https://raw.githubusercontent.com/antononcube/SystemModeling/master/Projects/Coronavirus-propagation-dynamics/WL/EpidemiologyModels.m"]
];

If[Length[DownValues[EpidemiologyModelModifications`GetStockSymbols]] == 0,
  Echo["EpidemiologyModelModifications.m", "Importing from GitHub:"];
  Import["https://raw.githubusercontent.com/antononcube/SystemModeling/master/Projects/Coronavirus-propagation-dynamics/WL/EpidemiologyModelModifications.m"]
];

If[Length[DownValues[SSparseMatrix`ToSSparseMatrix]] == 0,
  Echo["SSparseMatrix.m", "Importing from GitHub:"];
  Import["https://raw.githubusercontent.com/antononcube/MathematicaForPrediction/master/SSparseMatrix.m"]
];

If[Length[DownValues[HextileBins`HextileBins]] == 0,
  Echo["HextileBins.m", "Importing from GitHub:"];
  Import["https://raw.githubusercontent.com/antononcube/MathematicaForPrediction/master/Misc/HextileBins.m"]
];

If[Length[DownValues[EpidemiologyModelingSimulationFunctions`AggregateForCellIDs]] == 0,
  Echo["EpidemiologyModelingSimulationFunctions.m", "Importing from GitHub:"];
  Import["https://raw.githubusercontent.com/antononcube/SystemModeling/master/Projects/Coronavirus-propagation-dynamics/WL/EpidemiologyModelingSimulationFunctions.m"]
];


(**************************************************************)
(* Data reading function definition                           *)
(**************************************************************)

Clear[MultiSiteModelReadData];

MultiSiteModelReadData[] :=
    Block[{},

      If[! TrueQ[Head[dsUSCountyRecords] === Dataset],
        dsUSCountyRecords = ResourceFunction["ImportCSVToDataset"]["https://raw.githubusercontent.com/antononcube/SystemModeling/master/Data/dfUSACountyRecords.csv"];
      ];

      If[! TrueQ[Head[dsUSAAirportToAirportTravelers] === Dataset],
        dsUSAAirportToAirportTravelers = ResourceFunction["ImportCSVToDataset"]["https://raw.githubusercontent.com/antononcube/SystemModeling/master/Data/dfUSAAirportToAirportTravelers-2018.csv"];
      ];

      If[! TrueQ[Head[dsUSAAirportToAirportTravelers] === Dataset],
        dsUSAAirportToAirportTravelers = ResourceFunction["ImportCSVToDataset"]["https://raw.githubusercontent.com/antononcube/SystemModeling/master/Data/dfUSAAirportToAirportTravelers-2018.csv"];
      ];

      If[! TrueQ[Head[dsNYDataCounties] === Dataset],
        dsNYDataCounties = ResourceFunction["ImportCSVToDataset"]["https://raw.githubusercontent.com/nytimes/covid-19-data/master/us-counties.csv"];
        dsNYDataCounties = dsNYDataCounties[All, AssociationThread[Capitalize /@ Keys[#], Values[#]] &];
        dsNYDataCountiesLastDay = Dataset[Last[KeySort[GroupBy[Normal[dsNYDataCounties], #Date &]]]];
        dsNYDataCountiesLastDay = Dataset[JoinAcross[Normal[dsNYDataCountiesLastDay], Normal[dsUSCountyRecords[All, {"FIPS", "Lat", "Lon", "Population"}]], Key["Fips"] -> Key["FIPS"]]];
      ];

    ];

(**************************************************************)
(* Functions definition                                       *)
(**************************************************************)


Clear[MultiSiteModelSimulation];

MultiSiteModelSimulation[ aParams_Association ] :=
    Block[{ aExportParams = aParams,
      singleSiteModelFunc, maxTime, cellRadius, trafficFraction, includeBirthsTermQ, quarantineStart, quarantineDuration,
      quarantineContactRateFactor, quarantineTrafficFractionFactor,
      quarantineAirlinePassengerFactor, exportFileNamePrefix, exportSolutionsQ,
      cellRadiusDegrees,
      aLonLatPopulation,
      aGrid,
      matAT,
      aAirportData,
      aCellIDToFAACode,
      aFAACodeToCellID,
      dsQuery,
      aPopulations,
      aICPopulations,
      matGroundTraffic,
      matHexagonCellsTraffic,
      grHexagonCells,
      aICTotalPopulations,
      aICSusceptiblePopulations,
      aInfected,
      aICInfected,
      aDead,
      aICDead,
      model1,
      modelMultiSite,
      aSolMultiSite,
      aSolData,
      dsSolData,
      lsSolDataColumnNames,
      timeStamp
    },


      (*-----------------------------------------------------*)
      (* Assign parameters                                   *)
      (*-----------------------------------------------------*)

      {singleSiteModelFunc, maxTime, cellRadius, trafficFraction, includeBirthsTermQ, quarantineStart, quarantineDuration,
        quarantineContactRateFactor, quarantineTrafficFractionFactor,
        quarantineAirlinePassengerFactor, exportFileNamePrefix, exportSolutionsQ} =
          aParams /@
              {"singleSiteModelFunc", "maxTime", "cellRadius", "trafficFraction",
                "includeBirthsTermQ", "quarantineStart", "quarantineDuration",
                "quarantineContactRateFactor", "quarantineTrafficFractionFactor",
                "quarantineAirlinePassengerFactor", "exportFileNamePrefix", "exportSolutionsQ"};

      (*-----------------------------------------------------*)
      (* Read data                                           *)
      (*-----------------------------------------------------*)

      Print[Style["\tRead data...", Bold, Purple]];

      MultiSiteModelReadData[];

      Print[Style["\tRead data DONE", Bold, Purple]];

      (*-----------------------------------------------------*)
      (* Simulation initialization                           *)
      (*-----------------------------------------------------*)

      Print[Style["\tSimulation initialization...", Bold, Purple]];

      cellRadiusDegrees = QuantityMagnitude[cellRadius] / ((2 Pi * QuantityMagnitude[UnitConvert[Quantity[6378.14, "Kilometers"], "Miles"]]) / 360);

      Print["Make hex-tiling grid object over USA county coordinates..."];

      aLonLatPopulation = Association@Map[Most[#] -> Last[#] &, Values /@ Normal[dsUSCountyRecords[All, {"Lon", "Lat", "Population"}]]];
      Print["Length[aLonLatPopulation] = ", Length[aLonLatPopulation]];

      aGrid = MakeHexGrid[Keys[aLonLatPopulation], cellRadiusDegrees];

      Print[ Graphics[{FaceForm[LightBlue], EdgeForm[Red], Values[Map[#Cell &, aGrid["Cells"]]]}, Frame -> True] ];

      Print["Make airport-to-airport contingency matrix..."];

      matAT = ResourceFunction["CrossTabulate"][dsUSAAirportToAirportTravelers, "Sparse" -> True];
      matAT = ToSSparseMatrix[matAT];

      Print[MatrixPlot[matAT, ImageSize->Small]];

      Print["Associate airports with cell ID's ..."];

      aAirportData = Association[{#Lon, #Lat} -> #FAACode & /@ Normal[dsUSAAirportRecords]];

      aCellIDToFAACode = AggregateForCellIDs[aGrid, aAirportData, "AggregationFunction" -> Identity];

      aFAACodeToCellID = Association[Flatten[Thread[Reverse[#]] & /@ Normal[aCellIDToFAACode]]];

      Print["Modify the airport - to - airport contingency matrix to cellID -to-cellID ..."];

      dsQuery = dsUSAAirportToAirportTravelers[All, Join[#, <|"From" -> aFAACodeToCellID[#From], "To" -> aFAACodeToCellID[#To]|>] &];

      matAT = ResourceFunction["CrossTabulate"][dsQuery, "Sparse" -> True];
      matAT = ToSSparseMatrix[matAT];

      matAT = ImposeColumnNames[matAT, ToString /@ Range[Dimensions[aGrid["AdjacencyMatrix"]][[2]]]];
      matAT = ImposeRowNames[matAT, ToString /@ Range[Dimensions[aGrid["AdjacencyMatrix"]][[1]]]];

      Print["Make grid ID's populations:"];

      aPopulations = Association@Map[{#Lon, #Lat} -> #Population &, Normal[dsUSCountyRecords]];

      aICPopulations = KeySort[AggregateForCellIDs[aGrid, aPopulations]];

      Print["Check aICPopulations has keys that correspond to the adjacency matrix:"];

      Print[
        Sort[Keys[aICPopulations]] == Range[Dimensions[aGrid["AdjacencyMatrix"]][[2]]]
      ];

      Print["Ground traffic matrix..."];

      (* Here we use a simple heuristic: the traffic between two nodes is a certain fraction of the sum of the populations at those two nodes.
      The traffic fraction can be constant or seasonal (time dependent). *)

      Print["Here is the corresponding, heuristic traveling patterns matrix:"];

      matGroundTraffic = SparseArray[Map[(List @@ #) -> trafficFraction * Mean[Map[aICPopulations[#] &, List @@ #]] &, Most[ArrayRules[aGrid["AdjacencyMatrix"]]][[All, 1]]]];

      Print["Here we make the traveling patterns matrix time-dependent in order to be able to simulate quarantine scenarios:"];

      If[quarantineStart < maxTime && quarantineTrafficFractionFactor != 1,
        matGroundTraffic = matGroundTraffic * Piecewise[{{1, t < quarantineStart}, {quarantineTrafficFractionFactor, quarantineStart <= t <= quarantineStart + quarantineDuration}}, 1];
      ];

      Print["Here we make a constant traveling matrix and summarize it:"];

      Print[
        Block[{matTravel = Normal[matGroundTraffic] /. t -> 1.0},
          {ResourceFunction["RecordsSummary"][Flatten[matTravel], "All elements"][[1]],
            ResourceFunction["RecordsSummary"][Select[Flatten[matTravel], # > 0 &],
              "Non-zero elements"][[1]], MatrixPlot[matTravel, ImageSize -> Small]}
        ]
      ];

      (* Add traffic matrices *)

      MinMax[Normal[Clip[(SparseArray[matAT] / 365.) * quarantineAirlinePassengerFactor, {1, 100000}, {0, 100000}]]];

      matHexagonCellsTraffic = matGroundTraffic * trafficFraction + Clip[(SparseArray[matAT] / 365.) * quarantineAirlinePassengerFactor, {1, 100000}, {0, 100000}];

      (* Put the diagonals are zero (no point changing the ODE's based on the diagonal elements) : *)

      matHexagonCellsTraffic =
          SparseArray[
            DeleteCases[ArrayRules[matHexagonCellsTraffic],
              HoldPattern[{x_Integer, x_Integer} -> _]],
            Dimensions[matHexagonCellsTraffic]];

      (* Here we make a constant traveling matrix and summarize it : *)

      Print @
          Block[{matTravel = Normal[matHexagonCellsTraffic] /. t -> 1.0},
            {ResourceFunction["RecordsSummary"][Flatten[matTravel], "All elements"][[1]], ResourceFunction["RecordsSummary"][Select[Flatten[matTravel], # > 0 &], "Non-zero elements"][[1]], MatrixPlot[matTravel, ImageSize -> Small]}
          ];

      Print[ "Make grid graph (to check and visualize):" ];

      (* New Yorkers fleeing to FLL : *)

      (*grScenario=ToGraph[aGrid];
      HighlightGraph[grScenario,FindShortestPath[grScenario,228,203]]*)

      grHexagonCells = ToGraph[Join[aGrid, <|"AdjacencyMatrix" -> Unitize[SparseArray[Normal[matHexagonCellsTraffic] /. t -> 1.]]|>], EdgeStyle -> Opacity[0.2], VertexSize -> 0.45];

      Print[" Make grid ID's infected cases and deaths..."];

      aInfected = Association@Map[{#Lon, #Lat} -> #Cases &, Normal[dsNYDataCountiesLastDay]];
      aICInfected = AggregateForCellIDs[aGrid, aInfected];

      aDead = Association@Map[{#Lon, #Lat} -> #Deaths &, Normal[dsNYDataCountiesLastDay]];
      aICDead = AggregateForCellIDs[aGrid, aDead];

      (* Total populations *)

      (* Subtract from the populations the dead :*)

      aICTotalPopulations = Merge[{aICPopulations, aICDead}, If[Length[#] > 1, Subtract @@ #, #[[1]]] &];

      Print[ "Check total populations keys:" ];
      Print[ Sort[Keys[aICTotalPopulations]] == Range[Dimensions[matHexagonCellsTraffic][[2]]] ];

      (* Susceptible populations*)

      aICSusceptiblePopulations = Merge[{aICTotalPopulations, aICInfected}, If[Length[#] > 1, Subtract @@ #, #[[1]]] &];

      Print[ "Check susceptible populations keys:" ];
      Print[ Sort[Keys[aICSusceptiblePopulations]] == Range[Dimensions[matHexagonCellsTraffic][[2]]] ];

      (* Verification*)

      Print["Check that the populations should \"balance out\" :"];

      Print[ MinMax[Merge[{aICTotalPopulations, -aICSusceptiblePopulations, -aICInfected}, Total]]];

      Print[Style["\tSimulation initialization DONE", Bold, Purple]];

      (*-----------------------------------------------------*)
      (* Single-site "seed" model                            *)
      (*-----------------------------------------------------*)

      Print[Style["\tSingle-site \"seed\" model...", Bold, Purple]];

      (* In this section we create a single-site model that is being replicated over the graph nodes. (The rates and initial conditions are replicated for all nodes.) *)

      model1 = singleSiteModelFunc[t, "InitialConditions" -> True, "RateRules" -> True, "TotalPopulationRepresentation" -> "AlgebraicEquation", "BirthsTerm" -> TrueQ[includeBirthsTermQ]];

      (* Quarantine scenarios functions: *)

      model1 =
          SetRateRules[
            model1,
            <|\[Beta][ISSP] -> 0.56 * Piecewise[{{1, t < quarantineStart}, {quarantineContactRateFactor, quarantineStart <= t <= quarantineStart + quarantineDuration}}, 1],
              \[Beta][INSP] -> 0.56 * Piecewise[{{1, t < quarantineStart}, {quarantineContactRateFactor, quarantineStart <= t <= quarantineStart + quarantineDuration}}, 1]|>
          ];

      (* Number of beds per 1000 people: *)

      model1 = SetRateRules[model1, <|nhbr[TP] -> numberOfHospitalBedsPer1000 / 1000|>];

      Print[Style["\tSingle-site \"seed\" model DONE", Bold, Purple]];

      (*-----------------------------------------------------*)
      (* Main multi-site workflow                            *)
      (*-----------------------------------------------------*)

      Print[Style["\tMain multi-site model workflow", Bold, Purple]];

      (* In this section we do the model extension and simulation over a the hexagonal cells graph and the corresponding constant traveling patterns matrix. *)

      (* Here we scale the SEI2R model with the grid graph traveling matrix: *)
      Print["Scale the single-site model..."];

      Print @
          AbsoluteTiming[
            modelMultiSite =
                ToSiteCompartmentsModel[model1, matHexagonCellsTraffic,
                  "MigratingPopulations" -> Automatic];
          ];

      (* Change the initial conditions with the determined the total, susceptible, and infected populations for each hexagonal cell: *)
      Print["Change the initial conditions with the determined the total, susceptible, and infected populations for each hexagonal cell..."];

      Print @
          AbsoluteTiming[
            modelMultiSite =
                SetInitialConditions[
                  modelMultiSite,
                  Join[
                    Join[Association@Map[#[0] -> 0 &, GetPopulationSymbols[modelMultiSite, "Total Population"]], Association[KeyValueMap[TP[#1][0] -> #2 &, aICTotalPopulations]]],
                    Join[Association@Map[#[0] -> 0 &, GetPopulationSymbols[modelMultiSite, "Susceptible Population"]], Association[KeyValueMap[SP[#1][0] -> #2 &, aICSusceptiblePopulations]]],
                    Join[Association@Map[#[0] -> 0 &, GetPopulationSymbols[modelMultiSite, "Infected Normally Symptomatic Population"]], Association[KeyValueMap[INSP[#1][0] -> #2 &, aICInfected]]],
                    Association@Map[#[0] -> 0 &, GetPopulationSymbols[modelMultiSite, "Infected Severely Symptomatic Population"]]
                  ]
                ];
          ];



      (* Solve the system of ODE's of the scaled model: *)
      Print["Solve the system of ODE's of the scaled model..."];

      Print @
          AbsoluteTiming[
            aSolMultiSite = Association@First@
                NDSolve[
                  Join[
                    modelMultiSite["Equations"] //.
                        Join[ToAssociation[modelMultiSite["InitialConditions"]],
                          modelMultiSite["RateRules"]],
                    modelMultiSite["InitialConditions"] //. modelMultiSite["RateRules"]
                  ],
                  GetStockSymbols[modelMultiSite],
                  {t, 0, maxTime}
                ];
          ];


      Print[Style["\tMain multi-site model workflow DONE", Bold, Purple]];

      (*-----------------------------------------------------*)
      (* Export results                                      *)
      (*-----------------------------------------------------*)

      Print[Style["\tExport results...", Bold, Purple]];

      aExportParams = Join[ aExportParams, <|"NYTimesDate" -> dsNYDataCountiesLastDay[1, "Date"]|>];

      Print["Evaluate solutions over graph:"];

      Print @
          AbsoluteTiming[
            aSolData = Association@Map[# -> Round[EvaluateSolutionsOverGraphVertexes[grHexagonCells, modelMultiSite, #, aSolMultiSite, {1, maxTime, 1}], 0.001] &, Union[Values[modelMultiSite["Stocks"]]]];
          ];

      dsSolData = ConvertSolutions[aSolData, "Array"];
      lsSolDataColumnNames = {"Stock", "Node", "Time", "Value"};
      (*      ResourceFunction["GridTableForm"][RandomSample[dsSolData, 4], TableHeadings -> lsSolDataColumnNames]*)

      timeStamp = StringReplace[DateString["ISODateTime"], ":" -> "."];

      If[! StringQ[exportFileNamePrefix], exportFileNamePrefix = "COVID-19-MultiSiteModel-"];


      If[TrueQ[exportSolutionsQ],
        Print["Write files:"];
        Print @
            AbsoluteTiming[
              Export[FileNameJoin[{NotebookDirectory[], "ExperimentsData", StringJoin[exportFileNamePrefix, "GSTEM-Parameters-", timeStamp, ".csv"]}], Prepend[dsParams, {"Parameter", "Value"}], "CSV"];
              Export[FileNameJoin[{NotebookDirectory[], "ExperimentsData", StringJoin[exportFileNamePrefix, "GSTEM-Solutions-", timeStamp, ".csv"]}], Prepend[dsSolData, lsSolDataColumnNames], "CSV"];
            ];
      ];

      Print[Style["\tExport results DONE", Bold, Purple]];


      (*-----------------------------------------------------*)
      (* Results                                             *)
      (*-----------------------------------------------------*)

      <|
        "Grid" -> aGrid,
        "Graph" -> grHexagonCells,
        "TravelMatrix" -> matHexagonCellsTraffic,
        "SingleSiteModel" -> model1,
        "MultiSiteModel" -> modelMultiSite,
        "MultiSiteSolution" -> aSolMultiSite
      |>

    ];
