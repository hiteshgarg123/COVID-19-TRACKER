import 'dart:io';

import 'package:covid_19_tracker/blocs/common_bloc.dart';
import 'package:covid_19_tracker/data/data.dart';
import 'package:covid_19_tracker/data/hive_boxes.dart';
import 'package:covid_19_tracker/models/worldData.dart';
import 'package:covid_19_tracker/notifiers/theme_notifier.dart';
import 'package:covid_19_tracker/pages/countryWiseStats.dart';
import 'package:covid_19_tracker/pages/indiaStats.dart';
import 'package:covid_19_tracker/utils/app_theme.dart';
import 'package:covid_19_tracker/utils/dark_theme_preference.dart';
import 'package:covid_19_tracker/widgets/infoWidget.dart';
import 'package:covid_19_tracker/widgets/mostAffectedCountriesWidget.dart';
import 'package:covid_19_tracker/widgets/pieChart.dart';
import 'package:covid_19_tracker/widgets/platform_alert_dialog.dart';
import 'package:covid_19_tracker/widgets/worldWideWidget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  WorldData worldCachedData;
  List countriesCachedData;
  Box<WorldData> worldDataBox;
  Box countryDataBox;
  CommonBloc bloc;
  var _darkModeEnabled = false;

  void initState() {
    super.initState();
    bloc = Provider.of<CommonBloc>(context, listen: false);
    getCachedData();
    updateData();
  }

  @override
  void dispose() {
    bloc.disposeWorldandCountryDataStreams();
    super.dispose();
  }

  void getCachedData() {
    try {
      worldDataBox = Hive.box<WorldData>(HiveBoxes.worldData);
      countryDataBox = Hive.box(HiveBoxes.countriesData);
      worldCachedData =
          worldDataBox.isNotEmpty ? worldDataBox.values.last : null;
      countriesCachedData =
          countryDataBox.isNotEmpty ? countryDataBox.values.last : null;
    } catch (_) {
      showAlertDialog(
        context: context,
        titleText: 'Error Reading Data',
        contentText:
            'Can\'t read data from storage, Contact support or try again later',
        defaultActionButtonText: 'Ok',
      );
    }
  }

  Future<void> updateData() async {
    try {
      await bloc.getCombinedData();
    } on SocketException catch (_) {
      showAlertDialog(
        context: context,
        titleText: 'Connection error',
        contentText: 'Could not retrieve latest data, Please try again later.',
        defaultActionButtonText: 'Ok',
      );
    } on Response catch (response) {
      showAlertDialog(
        context: context,
        titleText: response.statusCode.toString(),
        contentText: 'Error Retrieving Data',
        defaultActionButtonText: 'Ok',
      );
    } catch (_) {
      showAlertDialog(
        context: context,
        titleText: 'Unknown Error',
        contentText: 'Please try again later.',
        defaultActionButtonText: 'Ok',
      );
    }
  }

  Widget _buildProgressIndicator() {
    return Container(
      height: 100.0,
      child: SpinKitFadingCircle(
        color: primaryBlack,
      ),
    );
  }

  Widget _buildWorldWidePannel(
    bool isLoading,
  ) {
    if (isLoading && worldDataBox.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(50.0),
        child: _buildProgressIndicator(),
      );
    }
    return WorldWideWidget(
      worldData: isLoading ? worldCachedData : bloc.worldData,
    );
  }

  Widget _buildMostAffectedCountriesPannel(
    bool isLoading,
  ) {
    if (isLoading && countryDataBox.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(50.0),
        child: _buildProgressIndicator(),
      );
    }
    return MostAffectedWidget(
      countryData: isLoading ? countriesCachedData : bloc.countriesData,
    );
  }

  Widget _buildPieChartPannel(bool isLoading) {
    if (isLoading && worldDataBox.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(50.0),
        child: _buildProgressIndicator(),
      );
    }
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          15.0,
        ),
      ),
      margin: const EdgeInsets.only(
        left: 10.0,
        right: 10.0,
        bottom: 10.0,
      ),
      color: Colors.amber[300],
      elevation: 4.0,
      child: PieChartWidget(
        total: double.tryParse(
          isLoading ? worldCachedData.cases : bloc.worldData.cases,
        ),
        active: double.tryParse(
          isLoading ? worldCachedData.active : bloc.worldData.active,
        ),
        recovered: double.tryParse(
          isLoading ? worldCachedData.recovered : bloc.worldData.recovered,
        ),
        deaths: double.tryParse(
          isLoading ? worldCachedData.deaths : bloc.worldData.deaths,
        ),
        totalColor: Colors.red[400],
        activeColor: Colors.blue,
        recoveredColor: Colors.green[400],
        deathsColor: Colors.grey[400],
      ),
    );
  }

  Future<void> onThemeChange(ThemeNotifier themeNotifier) async {
    _darkModeEnabled = !_darkModeEnabled;
    themeNotifier.setTheme(
        _darkModeEnabled ? AppTheme.darkTheme() : AppTheme.lightTheme());
    await DarkThemePreference().setDarkTheme(_darkModeEnabled);
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    _darkModeEnabled = (themeNotifier.getTheme() == AppTheme.darkTheme());
    AppBar appbar = AppBar(
      title: const Text('COVID-19 TRACKER'),
      elevation: 2.0,
      actions: [
        AnimatedSwitcher(
          duration: const Duration(seconds: 3),
          child: IconButton(
            icon: _darkModeEnabled
                ? Icon(Icons.wb_sunny_outlined)
                : Icon(Icons.nights_stay_outlined),
            tooltip: 'Change Theme',
            onPressed: () => onThemeChange(themeNotifier),
          ),
        ),
      ],
    );
    final height = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: appbar,
      body: LiquidPullToRefresh(
        showChildOpacityTransition: false,
        onRefresh: () => updateData(),
        height: 60.0,
        animSpeedFactor: 5.0,
        // backgroundColor: ,
        color: Theme.of(context).highlightColor,
        child: Builder(
          builder: (BuildContext context) {
            return WillPopScope(
              onWillPop: () => bloc.onWillPop(context),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      margin: const EdgeInsets.only(bottom: 5.0),
                      height: (height -
                              (appbar.preferredSize.height +
                                  MediaQuery.of(context).padding.top)) *
                          0.1,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10.0,
                        vertical: 2.0,
                      ),
                      color: Colors.orange[100],
                      child: Text(
                        StaticData.quote,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10.0,
                        horizontal: 10.0,
                      ),
                      child: Container(
                        width: MediaQuery.of(context).size.width,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              'Worldwide',
                              style: Theme.of(context).textTheme.headline1,
                            ),
                            SizedBox(
                              width: 10.0,
                            ),
                            Expanded(
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: <Widget>[
                                  GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) {
                                          return CountryWiseStats();
                                        },
                                      ),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(7.0),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).buttonColor,
                                        borderRadius:
                                            BorderRadius.circular(15.0),
                                      ),
                                      child: Text(
                                        'Regional',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headline2,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) {
                                          return IndiaStats();
                                        },
                                      ),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(7.0),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(15.0),
                                        color: Theme.of(context).buttonColor,
                                      ),
                                      child: Text(
                                        'India\'s Stats ',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headline2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    StreamBuilder<bool>(
                      stream: bloc.dataLoadingStream,
                      initialData: true,
                      builder: (context, snapshot) {
                        return _buildWorldWidePannel(
                          snapshot.data,
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10.0,
                        vertical: 10.0,
                      ),
                      child: Text(
                        'Most Affected Countries',
                        style: Theme.of(context).textTheme.headline1,
                      ),
                    ),
                    StreamBuilder<bool>(
                      stream: bloc.dataLoadingStream,
                      initialData: true,
                      builder: (context, snapshot) {
                        return _buildMostAffectedCountriesPannel(
                          snapshot.data,
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10.0,
                        vertical: 10.0,
                      ),
                      child: Text(
                        'Statistics...',
                        style: Theme.of(context).textTheme.headline1,
                      ),
                    ),
                    StreamBuilder<bool>(
                      stream: bloc.dataLoadingStream,
                      initialData: true,
                      builder: (context, snapshot) {
                        return _buildPieChartPannel(
                          snapshot.data,
                        );
                      },
                    ),
                    const SizedBox(
                      height: 10.0,
                    ),
                    InfoWidget(),
                    const SizedBox(
                      height: 10.0,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10.0,
                        vertical: 10.0,
                      ),
                      child: Center(
                        child: Text(
                          'WE STAND TOGETHER TO FIGHT WITH THIS',
                          style: Theme.of(context).textTheme.headline3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
