// ignore_for_file: use_build_context_synchronously, type_literal_in_constant_pattern

import 'dart:io';
import 'package:tetra_stats/data_objects/beta_record.dart';
import 'package:tetra_stats/data_objects/minomuncher.dart';
import 'package:tetra_stats/data_objects/tetrio_multiplayer_replay.dart';
import 'package:tetra_stats/utils/relative_timestamps.dart';
import 'package:tetra_stats/widgets/apl_ranges.dart';
import 'package:tetra_stats/widgets/apm_pps_ranges.dart';
import 'package:tetra_stats/widgets/cheese_ds_ratio_thingy.dart';
import 'package:tetra_stats/widgets/clear_types_thingy.dart';
import 'package:tetra_stats/widgets/compare_thingy.dart';
import 'package:tetra_stats/widgets/efficiency_ranges.dart';
import 'package:tetra_stats/widgets/future_error.dart';
import 'package:tetra_stats/widgets/kills_deaths_thingy.dart';
import 'package:tetra_stats/widgets/list_tile_trailing_stats.dart';
import 'package:tetra_stats/widgets/pps_distribution_thingy.dart';
import 'package:tetra_stats/widgets/pps_surge_radars_thingy.dart';
import 'package:tetra_stats/widgets/sankey_thingy.dart';
import 'package:tetra_stats/widgets/text_timestamp.dart';
import 'package:tetra_stats/widgets/vs_graphs.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tetra_stats/gen/strings.g.dart';
import 'package:tetra_stats/utils/open_in_browser.dart';
import 'package:tetra_stats/widgets/well_columns_thingy.dart';
import 'package:window_manager/window_manager.dart';

import '../main.dart';


int roundSelector = -1; // -1 = match averages, otherwise round number-1
List<DropdownMenuItem> rounds = []; // index zero will be match stats
Mod mod = Mod.info; // thing, that determines if i should show default stats or freyhoe stats
bool timeWeightedStatsAvaliable = true;
int greenSidePlayer = 0;
int redSidePlayer = 1;
late String oldWindowTitle;

Duration framesToTime(int frames){
  return Duration(microseconds: frames~/6e-5);
}

class TlMatchResultView extends StatefulWidget {
  final BetaRecord record;
  final String initPlayerId;
  const TlMatchResultView({super.key, required this.record, required this.initPlayerId});

  @override
  State<StatefulWidget> createState() => TlMatchResultState();
}

class TlMatchResultState extends State<TlMatchResultView> {
  late Future<ReplayData?> replayData;
  late Duration time;
  late String readableTime;
  late String reason;
  Duration totalTime = const Duration();
  List<Duration> roundLengths = [];
  late bool initPlayerWon;

  @override
  void initState(){
    rounds = [DropdownMenuItem(value: -1, child: Text(t.tlMatchView.match))];
    rounds.addAll([for (int i = 0; i < widget.record.results.rounds.length; i++) DropdownMenuItem(value: i, child: Text(t.tlMatchView.roundNumber(n: i+1)))]);
    greenSidePlayer = widget.record.results.leaderboard.indexWhere((element) => element.id == widget.initPlayerId);
    redSidePlayer = widget.record.results.leaderboard.indexWhere((element) => element.id != widget.initPlayerId);
    for (var round in widget.record.results.rounds){
      var longerLifetime = round[0].lifetime.compareTo(round[1].lifetime) == 1 ? round[0].lifetime : round[1].lifetime;
      roundLengths.add(longerLifetime);
      totalTime += longerLifetime;
    }
    initPlayerWon = widget.record.results.leaderboard[greenSidePlayer].wins > widget.record.results.leaderboard[redSidePlayer].wins;
    if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS){
      windowManager.getTitle().then((value) => oldWindowTitle = value);
      windowManager.setTitle("Tetra Stats: ${widget.record.results.leaderboard[greenSidePlayer].username.toUpperCase()} ${t.tlMatchView.vs} ${widget.record.results.leaderboard[redSidePlayer].username.toUpperCase()} ${timestamp(widget.record.ts)}");
    }
    super.initState();
  }

  @override
  void dispose(){
    roundSelector = -1;
    if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) windowManager.setTitle(oldWindowTitle);
    super.dispose();
  }

  Widget mobileSelector(){
    if (roundSelector.isNegative){
      time = totalTime;
      readableTime = !time.isNegative ? "${t.tlMatchView.matchLength}: ${time.inMinutes}:${secs.format(time.inMicroseconds /1000000 % 60)}" : "${t.tlMatchView.matchLength}: ---";
    }else{
      time = roundLengths[roundSelector];
      int alive = widget.record.results.rounds[roundSelector].indexWhere((element) => element.alive);
      readableTime = "${t.tlMatchView.roundLength}: ${!time.isNegative ? "${time.inMinutes}:${secs.format(time.inMicroseconds /1000000 % 60)}" : "---"}\n${t.tlMatchView.winner}: ${alive == -1 ? "idk" : widget.record.results.rounds[roundSelector][alive].username}";
    }
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text("${t.tlMatchView.statsFor}: ",
          style: const TextStyle(color: Colors.white, fontSize: 25)),
          DropdownButton(items: rounds, value: roundSelector, onChanged: ((value) {
            roundSelector = value;
            setState(() {});
          }),),
        ],
      ),
    );
  }

  Widget buildComparison(double width, bool showMobileSelector){
    bool bigScreen = width >= 768;
    return Column(
      children: [
        SizedBox(
          width: width,
          height: !widget.record.stub && showMobileSelector ? MediaQuery.of(context).size.height - 96 : MediaQuery.of(context).size.height - 56,
          child: NestedScrollView(
              headerSliverBuilder: (context, value) {
                return [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                colors: const [Colors.green, Colors.transparent],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                stops: [0.0, initPlayerWon ? 0.4 : 0.0],
                              )),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                                child: Column(children: [
                                  Text(widget.record.results.leaderboard[greenSidePlayer].username, style: bigScreen ? const TextStyle(
                                fontFamily: "Eurostile Round Extended",
                                fontSize: 28) : const TextStyle()),
                                  Text(widget.record.results.leaderboard[greenSidePlayer].wins.toString(), style: const TextStyle(
                                fontFamily: "Eurostile Round Extended",
                                fontSize: 42))
                                ]),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Text("VS"),
                          ),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                colors: const [Colors.red, Colors.transparent],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                stops: [0.0, !initPlayerWon ? 0.4 : 0.0],
                              )),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                                child: Column(children: [
                                  Text(widget.record.results.leaderboard[redSidePlayer].username, style:  bigScreen ? const TextStyle(
                                fontFamily: "Eurostile Round Extended",
                                fontSize: 28) : const TextStyle()),
                                  Text(widget.record.results.leaderboard[redSidePlayer].wins.toString(), style: const TextStyle(
                                fontFamily: "Eurostile Round Extended",
                                fontSize: 42))
                                ]),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (showMobileSelector) SliverToBoxAdapter(child: mobileSelector()),
                  if (showMobileSelector) SliverToBoxAdapter(child: Center(child: Text(readableTime, textAlign: TextAlign.center))),
                  const SliverToBoxAdapter(
                    child: Divider(),
                  )
                ];
              },
              body: ListView(
                children: [
                  Column(
                    children: [
                        CompareThingy(
                          label: t.stats.apm.short,
                          greenSide: roundSelector.isNegative ? widget.record.results.leaderboard[greenSidePlayer].stats.apm : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id == widget.initPlayerId).stats.apm,
                          redSide: roundSelector == -1 ? widget.record.results.leaderboard[redSidePlayer].stats.apm : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id != widget.initPlayerId).stats.apm,
                          fractionDigits: 2,
                          higherIsBetter: true,
                        ),
                        CompareThingy(
                          label: t.stats.pps.short,
                          greenSide: roundSelector.isNegative ? widget.record.results.leaderboard[greenSidePlayer].stats.pps : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id == widget.initPlayerId).stats.pps,
                          redSide: roundSelector == -1 ? widget.record.results.leaderboard[redSidePlayer].stats.pps : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id != widget.initPlayerId).stats.pps,
                          fractionDigits: 2,
                          higherIsBetter: true,
                        ),
                        CompareThingy(
                          label: t.stats.vs.short,
                          greenSide: roundSelector.isNegative ? widget.record.results.leaderboard[greenSidePlayer].stats.vs : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id == widget.initPlayerId).stats.vs,
                          redSide: roundSelector == -1 ? widget.record.results.leaderboard[redSidePlayer].stats.vs : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id != widget.initPlayerId).stats.vs,
                          fractionDigits: 2,
                          higherIsBetter: true,
                        ),
                        if (widget.record.gamemode == "league") CompareThingy(greenSide: roundSelector.isNegative ? widget.record.results.leaderboard[greenSidePlayer].stats.garbageSent : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id == widget.initPlayerId).stats.garbageSent,
                          redSide: roundSelector.isNegative ? widget.record.results.leaderboard[redSidePlayer].stats.garbageSent : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id != widget.initPlayerId).stats.garbageSent,
                          label: t.stats.sent, higherIsBetter: true),
                        if (widget.record.gamemode == "league") CompareThingy(greenSide: roundSelector.isNegative ? widget.record.results.leaderboard[greenSidePlayer].stats.garbageReceived : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id == widget.initPlayerId).stats.garbageReceived,
                          redSide: roundSelector.isNegative ? widget.record.results.leaderboard[redSidePlayer].stats.garbageReceived : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id != widget.initPlayerId).stats.garbageReceived,
                          label: t.stats.received, higherIsBetter: true),                    const Divider(),
                          Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(t.nerdStats,
                                    style: TextStyle(
                                        fontFamily: "Eurostile Round Extended",
                                        fontSize: bigScreen ? 42 : 28)),
                              ),
                              CompareThingy(
                                label: t.stats.app.short,
                                greenSide: roundSelector.isNegative ? widget.record.results.leaderboard[greenSidePlayer].stats.nerdStats.app : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id == widget.initPlayerId).stats.nerdStats.app,
                                redSide: roundSelector.isNegative ? widget.record.results.leaderboard[redSidePlayer].stats.nerdStats.app : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id != widget.initPlayerId).stats.nerdStats.app,
                                fractionDigits: 3,
                                higherIsBetter: true,
                              ),
                              CompareThingy(
                                label: t.stats.vsapm.short,
                                greenSide: roundSelector.isNegative ? widget.record.results.leaderboard[greenSidePlayer].stats.nerdStats.vsapm : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id == widget.initPlayerId).stats.nerdStats.vsapm,
                                redSide: roundSelector.isNegative ? widget.record.results.leaderboard[redSidePlayer].stats.nerdStats.vsapm : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id != widget.initPlayerId).stats.nerdStats.vsapm,
                                fractionDigits: 3,
                                higherIsBetter: true,
                              ),
                              CompareThingy(
                                label: t.stats.dss.short,
                                greenSide: roundSelector.isNegative ? widget.record.results.leaderboard[greenSidePlayer].stats.nerdStats.dss : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id == widget.initPlayerId).stats.nerdStats.dss,
                                redSide: roundSelector.isNegative ? widget.record.results.leaderboard[redSidePlayer].stats.nerdStats.dss : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id != widget.initPlayerId).stats.nerdStats.dss,
                                fractionDigits: 3,
                                higherIsBetter: true,
                              ),
                              CompareThingy(
                                label: t.stats.dsp.short,
                                greenSide: roundSelector.isNegative ? widget.record.results.leaderboard[greenSidePlayer].stats.nerdStats.dsp : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id == widget.initPlayerId).stats.nerdStats.dsp,
                                redSide: roundSelector.isNegative ? widget.record.results.leaderboard[redSidePlayer].stats.nerdStats.dsp : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id != widget.initPlayerId).stats.nerdStats.dsp,
                                fractionDigits: 3,
                                higherIsBetter: true,
                              ),
                              CompareThingy(
                                label: t.stats.appdsp.short,
                                greenSide: roundSelector.isNegative ? widget.record.results.leaderboard[greenSidePlayer].stats.nerdStats.appdsp : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id == widget.initPlayerId).stats.nerdStats.appdsp,
                                redSide: roundSelector.isNegative ? widget.record.results.leaderboard[redSidePlayer].stats.nerdStats.appdsp : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id != widget.initPlayerId).stats.nerdStats.appdsp,
                                fractionDigits: 3,
                                higherIsBetter: true,
                              ),
                              CompareThingy(
                                label: t.stats.cheese.short,
                                greenSide: roundSelector.isNegative ? widget.record.results.leaderboard[greenSidePlayer].stats.nerdStats.cheese : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id == widget.initPlayerId).stats.nerdStats.cheese,
                                redSide: roundSelector.isNegative ? widget.record.results.leaderboard[redSidePlayer].stats.nerdStats.cheese : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id != widget.initPlayerId).stats.nerdStats.cheese,
                                fractionDigits: 2,
                                higherIsBetter: false,
                              ),
                              CompareThingy(
                                label: t.stats.gbe.short,
                                greenSide: roundSelector.isNegative ? widget.record.results.leaderboard[greenSidePlayer].stats.nerdStats.gbe : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id == widget.initPlayerId).stats.nerdStats.gbe,
                                redSide: roundSelector.isNegative ? widget.record.results.leaderboard[redSidePlayer].stats.nerdStats.gbe : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id != widget.initPlayerId).stats.nerdStats.gbe,
                                fractionDigits: 3,
                                higherIsBetter: true,
                              ),
                              CompareThingy(
                                label: t.stats.nyaapp.short,
                                greenSide: roundSelector.isNegative ? widget.record.results.leaderboard[greenSidePlayer].stats.nerdStats.nyaapp : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id == widget.initPlayerId).stats.nerdStats.nyaapp,
                                redSide: roundSelector.isNegative ? widget.record.results.leaderboard[redSidePlayer].stats.nerdStats.nyaapp : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id != widget.initPlayerId).stats.nerdStats.nyaapp,
                                fractionDigits: 3,
                                higherIsBetter: true,
                              ),
                              CompareThingy(
                                label: t.stats.area.short,
                                greenSide: roundSelector.isNegative ? widget.record.results.leaderboard[greenSidePlayer].stats.nerdStats.area : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id == widget.initPlayerId).stats.nerdStats.area,
                                redSide: roundSelector.isNegative ? widget.record.results.leaderboard[redSidePlayer].stats.nerdStats.area : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id != widget.initPlayerId).stats.nerdStats.area,
                                fractionDigits: 2,
                                higherIsBetter: true,
                              ),
                              CompareThingy(
                                label: t.stats.etr.short,
                                greenSide: roundSelector.isNegative ? widget.record.results.leaderboard[greenSidePlayer].stats.estTr.esttr : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id == widget.initPlayerId).stats.estTr.esttr,
                                redSide: roundSelector.isNegative ? widget.record.results.leaderboard[redSidePlayer].stats.estTr.esttr : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id != widget.initPlayerId).stats.estTr.esttr,
                                fractionDigits: 2,
                                higherIsBetter: true,
                              ),
                              CompareThingy(
                                label: t.stats.opener.short,
                                greenSide: roundSelector.isNegative ? widget.record.results.leaderboard[greenSidePlayer].stats.playstyle.opener : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id == widget.initPlayerId).stats.playstyle.opener,
                                redSide: roundSelector.isNegative ? widget.record.results.leaderboard[redSidePlayer].stats.playstyle.opener : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id != widget.initPlayerId).stats.playstyle.opener,
                                fractionDigits: 3,
                                higherIsBetter: true,
                              ),
                              CompareThingy(
                                label: t.stats.plonk.short,
                                greenSide: roundSelector.isNegative ? widget.record.results.leaderboard[greenSidePlayer].stats.playstyle.plonk : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id == widget.initPlayerId).stats.playstyle.plonk,
                                redSide: roundSelector.isNegative ? widget.record.results.leaderboard[redSidePlayer].stats.playstyle.plonk : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id != widget.initPlayerId).stats.playstyle.plonk,
                                fractionDigits: 3,
                                higherIsBetter: true,
                              ),
                              CompareThingy(
                                label: t.stats.stride.short,
                                greenSide: roundSelector.isNegative ? widget.record.results.leaderboard[greenSidePlayer].stats.playstyle.stride : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id == widget.initPlayerId).stats.playstyle.stride,
                                redSide: roundSelector.isNegative ? widget.record.results.leaderboard[redSidePlayer].stats.playstyle.stride : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id != widget.initPlayerId).stats.playstyle.stride,
                                fractionDigits: 3,
                                higherIsBetter: true,
                              ),
                              CompareThingy(
                                label: t.stats.infds.short,
                                greenSide: roundSelector.isNegative ? widget.record.results.leaderboard[greenSidePlayer].stats.playstyle.infds : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id == widget.initPlayerId).stats.playstyle.infds,
                                redSide: roundSelector.isNegative ? widget.record.results.leaderboard[redSidePlayer].stats.playstyle.infds : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id != widget.initPlayerId).stats.playstyle.infds,
                                fractionDigits: 3,
                                higherIsBetter: true,
                              ),
                              VsGraphs(
                                roundSelector.isNegative ? widget.record.results.leaderboard[greenSidePlayer].stats.apm : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id == widget.initPlayerId).stats.apm,
                                roundSelector.isNegative ? widget.record.results.leaderboard[greenSidePlayer].stats.pps : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id == widget.initPlayerId).stats.pps,
                                roundSelector.isNegative ? widget.record.results.leaderboard[greenSidePlayer].stats.vs : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id == widget.initPlayerId).stats.vs,
                                roundSelector.isNegative ? widget.record.results.leaderboard[greenSidePlayer].stats.nerdStats : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id == widget.initPlayerId).stats.nerdStats,
                                roundSelector.isNegative ? widget.record.results.leaderboard[greenSidePlayer].stats.playstyle : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id == widget.initPlayerId).stats.playstyle,
                                roundSelector.isNegative ? widget.record.results.leaderboard[redSidePlayer].stats.apm : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id != widget.initPlayerId).stats.apm,
                                roundSelector.isNegative ? widget.record.results.leaderboard[redSidePlayer].stats.pps : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id != widget.initPlayerId).stats.pps,
                                roundSelector.isNegative ? widget.record.results.leaderboard[redSidePlayer].stats.vs : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id != widget.initPlayerId).stats.vs,
                                roundSelector.isNegative ? widget.record.results.leaderboard[redSidePlayer].stats.nerdStats : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id != widget.initPlayerId).stats.nerdStats,
                                roundSelector.isNegative ? widget.record.results.leaderboard[redSidePlayer].stats.playstyle : widget.record.results.rounds[roundSelector].firstWhere((element) => element.id != widget.initPlayerId).stats.playstyle,
                              )
                            ],
                          ),
                          // if (widget.record.ownId != widget.record.replayId) const Divider(),
                          // if (widget.record.ownId != widget.record.replayId) Column(
                          //   children: [
                          //     Padding(
                          //       padding: const EdgeInsets.only(bottom: 16),
                          //       child: Text("Handling",
                          //           style: TextStyle(
                          //               fontFamily: "Eurostile Round Extended",
                          //               fontSize: bigScreen ? 42 : 28)),
                          //     ),
                          //     CompareThingy(
                          //       greenSide: widget.record.endContext.firstWhere((element) => element.userId == widget.initPlayerId).handling.das,
                          //       redSide: widget.record.endContext.firstWhere((element) => element.userId != widget.initPlayerId).handling.das,
                          //       label: "DAS", fractionDigits: 1, postfix: "F",
                          //       higherIsBetter: false),
                          //     CompareThingy(
                          //       greenSide: widget.record.endContext.firstWhere((element) => element.userId == widget.initPlayerId).handling.arr,
                          //       redSide: widget.record.endContext.firstWhere((element) => element.userId != widget.initPlayerId).handling.arr,
                          //       label: "ARR", fractionDigits: 1, postfix: "F",
                          //       higherIsBetter: false),
                          //     CompareThingy(
                          //       greenSide: widget.record.endContext.firstWhere((element) => element.userId == widget.initPlayerId).handling.sdf,
                          //       redSide: widget.record.endContext.firstWhere((element) => element.userId != widget.initPlayerId).handling.sdf,
                          //       label: "SDF", prefix: "x",
                          //       higherIsBetter: true),
                          //     CompareBoolThingy(
                          //       greenSide: widget.record.endContext.firstWhere((element) => element.userId == widget.initPlayerId).handling.safeLock,
                          //       redSide: widget.record.endContext.firstWhere((element) => element.userId != widget.initPlayerId).handling.safeLock,
                          //       label: "Safe HD",
                          //       trueIsBetter: true)
                          //   ],
                          // )
                      ],
                    )
            ])),
        ),
        if (!widget.record.stub && showMobileSelector) SizedBox(
            width: width,
            height: 40.000000,
            child: SegmentedButton<Mod>(
              showSelectedIcon: false,
              selected: <Mod>{mod},
              segments: <ButtonSegment<Mod>>[
                ButtonSegment(
                  value: Mod.info,
                  label: Text(t.general)
                ),
                ButtonSegment(
                  value: Mod.analysis,
                  label: Text(t.analysis)
                )
              ],
              onSelectionChanged: (p0) {
                setState(() {
                  mod = p0.first;
                });
              },
            ),
          )
      ],
    );
  }

  Future<List<MinomuncherData>> ummm(String replayID) async {
    RawReplay replay = widget.record.replay ?? await teto.szyGetReplay(replayID);
    List<MinomuncherRaw> raw = await teto.minomuncherPostReplay(replay);
    return [for (MinomuncherRaw e in raw) e.data];
  }

  Widget buildFreyhoeComparison(double width, bool showMobileSelector){
    return Column(
      children: [
        SizedBox(
          width: width,
          height: !widget.record.stub && showMobileSelector ? MediaQuery.of(context).size.height - 96 : MediaQuery.of(context).size.height - 56,
          child: FutureBuilder<List<MinomuncherData>>(
            future: ummm(widget.record.replayID),
            builder: (context, snapshot) {
              switch (snapshot.connectionState){
                  case ConnectionState.none:
                  case ConnectionState.waiting:
                  case ConnectionState.active:
                    return const Center(child: CircularProgressIndicator());
                  case ConnectionState.done:
                if (snapshot.hasData){
                  return ListView(
                    children: [
                      ApmPpsThingy([for (MinomuncherData e in snapshot.data!) ApmPps(e.nick, e.openerAPM, e.APM, e.midgameAPM, e.openerPPS, e.PPS, e.midgamePPS)]),
                      AplThingy([for (MinomuncherData e in snapshot.data!) Apl(e.nick, e.upstackAPL, e.downstackAPL, e.cheeseAPL)], width > 768),
                      EffThingy([for (MinomuncherData e in snapshot.data!) Eff(e.nick, e.iEfficiency, e.tEfficiency, e.allspinEfficiency)], width > 768),
                      ClearTypesThingy([for (MinomuncherData e in snapshot.data!) e.clearTypes], width),
                      WellColumnsThingy([for (MinomuncherData e in snapshot.data!) e.wellColumns], [for (MinomuncherData e in snapshot.data!) e.nick], width),
                      PPSSurgeThingy([for (MinomuncherData e in snapshot.data!) e], width),
                      SankeyThingy([for (MinomuncherData e in snapshot.data!) e], width),
                      CheeseAndDSThingy([for (MinomuncherData e in snapshot.data!) e.attackCheesiness], [for (MinomuncherData e in snapshot.data!) e.downstackingRatio], [for (MinomuncherData e in snapshot.data!) e.nick]),
                      KillsDeathsThingy([for (MinomuncherData e in snapshot.data!) KD(e.nick, e.killStats, e.deathStats)], width),
                      PPSDistributionThingy([for (MinomuncherData e in snapshot.data!) e.ppsSegments], [for (MinomuncherData e in snapshot.data!) e.nick], width)
                    ],
                  );
                } if (snapshot.hasError){ return SizedBox(height: 720.0, child: FutureError(snapshot)); }
              }
              return const Text("what?");
            }
          ),
        ),
        if (!widget.record.stub && showMobileSelector) SizedBox(
            width: width,
            height: 40.000000,
            child: SegmentedButton<Mod>(
              showSelectedIcon: false,
              selected: <Mod>{mod},
              segments: <ButtonSegment<Mod>>[
                ButtonSegment(
                  value: Mod.info,
                  label: Text(t.general)
                ),
                ButtonSegment(
                  value: Mod.analysis,
                  label: Text(t.analysis)
                )
              ],
              onSelectionChanged: (p0) {
                setState(() {
                  mod = p0.first;
                });
              },
            ),
          )
      ],
    );
  }

  Widget buildRoundSelector(double width, double height){
    return Padding(
      padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0.0),
      child: Column(
        children: [
          SizedBox(
            width: width,
            height: height - 64 - 40,// - 72
            child: NestedScrollView(
              headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) { 
                return [
                  SliverToBoxAdapter(child: 
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            Text(t.tlMatchView.matchLength),
                            RichText(
                              text: !totalTime.isNegative ? TextSpan(
                              text: "${totalTime.inMinutes}:${NumberFormat("00", LocaleSettings.currentLocale.languageCode).format(totalTime.inSeconds%60)}",
                              style: const TextStyle(fontFamily: "Eurostile Round Extended", fontSize: 28, fontWeight: FontWeight.w500, color: Colors.white),
                              children: [TextSpan(text: ".${NumberFormat("000", LocaleSettings.currentLocale.languageCode).format(totalTime.inMilliseconds%1000)}", style: const TextStyle(fontFamily: "Eurostile Round", fontSize: 14, fontWeight: FontWeight.w100))]
                              ) : const TextSpan(
                              text: "-:--",
                              style: TextStyle(fontFamily: "Eurostile Round Extended", fontSize: 28, fontWeight: FontWeight.w500, color: Colors.grey),
                              children: [TextSpan(text: ".---", style: TextStyle(fontFamily: "Eurostile Round", fontSize: 14, fontWeight: FontWeight.w100))]
                              ),
                            )
                          ],),
                         if (widget.record.id != widget.record.replayID) Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                          Text(t.tlMatchView.numberOfRounds),
                          RichText(
                            text: TextSpan(
                              text: widget.record.results.rounds.length.toString(),
                              style: const TextStyle(
                                fontFamily: "Eurostile Round Extended",
                                fontSize: 28,
                                fontWeight: FontWeight.w500,
                                color: Colors.white
                                ),
                              ),
                            )
                        ],),
                      ],
                    )
                  ),
                  SliverToBoxAdapter(
                    child: TextButton( style: roundSelector == -1 ? ButtonStyle(backgroundColor: WidgetStatePropertyAll(Colors.grey.shade900)) : null,
                      onPressed: () {
                        roundSelector = -1;
                        setState(() {});
                      }, child: Text(t.tlMatchView.matchStats)),
                  )
                ];
               },
              body: ListView.builder(itemCount: widget.record.results.rounds.length,
                itemBuilder: (BuildContext context, int index) {
                  var accentColor = widget.record.results.rounds[index][0].id == widget.initPlayerId ? Colors.green : Colors.red;
                  var bgColor = roundSelector == index ? Colors.grey.shade900 : Colors.transparent;
                  var time = roundLengths[index];
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        stops: const [0, 0.05],
                        colors: [accentColor, bgColor]
                      )
                    ),
                    child: ListTile(
                      leading:RichText(
                        text: !time.isNegative ? TextSpan(
                          text: "${time.inMinutes}:${NumberFormat("00", LocaleSettings.currentLocale.languageCode).format(time.inSeconds%60)}",
                          style: const TextStyle(fontFamily: "Eurostile Round", fontSize: 22, fontWeight: FontWeight.w500, color: Colors.white),
                          children: [TextSpan(text: ".${NumberFormat("000", LocaleSettings.currentLocale.languageCode).format(time.inMilliseconds%1000)}", style: const TextStyle(fontFamily: "Eurostile Round", fontSize: 14, fontWeight: FontWeight.w100))]
                        ) : const TextSpan(
                          text: "-:--",
                          style: TextStyle(fontFamily: "Eurostile Round", fontSize: 22, fontWeight: FontWeight.w500, color: Colors.grey),
                          children: [TextSpan(text: ".---", style: TextStyle(fontFamily: "Eurostile Round", fontSize: 14, fontWeight: FontWeight.w100))]
                          ), 
                      ),
                      title: Text(widget.record.results.rounds[index][0].username, textAlign: TextAlign.center),
                      trailing: TrailingStats(
                        widget.record.results.rounds[index].firstWhere((element) => element.id == widget.initPlayerId).stats.apm,
                        widget.record.results.rounds[index].firstWhere((element) => element.id == widget.initPlayerId).stats.pps,
                        widget.record.results.rounds[index].firstWhere((element) => element.id == widget.initPlayerId).stats.vs,
                        widget.record.results.rounds[index].firstWhere((element) => element.id != widget.initPlayerId).stats.apm,
                        widget.record.results.rounds[index].firstWhere((element) => element.id != widget.initPlayerId).stats.pps,
                        widget.record.results.rounds[index].firstWhere((element) => element.id != widget.initPlayerId).stats.vs
                      ),
                      onTap:(){
                        roundSelector = index;
                        setState(() {});
                      },
                    ),
                  );
              })
            ),
          ),
          if (!widget.record.stub) SizedBox(
            width: width,
            height: 40.000000,
            child: SegmentedButton<Mod>(
              showSelectedIcon: false,
              selected: <Mod>{mod},
              segments: <ButtonSegment<Mod>>[
                ButtonSegment(
                  value: Mod.info,
                  label: Text(t.general)
                ),
                ButtonSegment(
                  value: Mod.analysis,
                  label: Text(t.analysis)
                )
              ],
              onSelectionChanged: (p0) {
                setState(() {
                  mod = p0.first;
                });
              },
            ),
          )
        ],
      ),
    );
  }
  
  Widget getMainWidget(Size size) {
    if (size.width <= 1200) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 768),
          child: mod == Mod.analysis ? buildFreyhoeComparison(size.width, true) : buildComparison(size.width, true)
        ),
      );
    } else {
      double comparisonWidth = size.width - 450 - 16;
      comparisonWidth = comparisonWidth > 768 ? 768 : comparisonWidth;
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          mod == Mod.analysis ? buildFreyhoeComparison(comparisonWidth, false) : buildComparison(comparisonWidth, false),
          buildRoundSelector(450, size.height)
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    if (widget.record.stub && mod == Mod.analysis) mod = Mod.info;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "${widget.record.results.leaderboard[greenSidePlayer].username.toUpperCase()} ${t.tlMatchView.vs} ${widget.record.results.leaderboard[redSidePlayer].username.toUpperCase()} ${widget.record.gamemode} ${timestamp(widget.record.ts)}",
          style: Theme.of(context).textTheme.titleMedium!.copyWith(fontSize: 28),
        ),
        actions: [
          PopupMenuButton(
            enabled: widget.record.gamemode == "league" && !widget.record.stub,
            itemBuilder: (BuildContext context) => <PopupMenuEntry>[
              PopupMenuItem(
                value: 1,
                child: Text(t.tlMatchView.downloadReplay),
              ),
              PopupMenuItem(
                value: 2,
                child: Text(t.tlMatchView.openReplay),
              )
            ],
            onSelected: (value) async {
              switch (value) {
                case 1:
                  await launchInBrowser(Uri.parse("https://inoue.szy.lol/api/replay/${widget.record.replayID}"));
                  break;
                case 2:
                  await launchInBrowser(Uri.parse("https://tetr.io/#r:${widget.record.replayID}"));
                  break;
                default:
              }
            })
        ]
      ),
      backgroundColor: Colors.black,
      body: getMainWidget(MediaQuery.of(context).size),
      );
  }
}

enum Mod {info, analysis}