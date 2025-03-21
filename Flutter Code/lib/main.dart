import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:postgres/postgres.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  String vati = "Loading...";
  String cena = "Loading...";
  String poraba = "Loading...";
  String tarifa = "Loading...";


  late PostgreSQLConnection connection;
  Timer? autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    connectToDatabase();
    fetchVati();
    fetchCena();
    fetchPoraba();
    fetchTarifa();

    autoRefreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      fetchCena();
      fetchPoraba();
      fetchVati();
      fetchTarifa();
    });
  }

  Future<void> connectToDatabase() async {
    connection = PostgreSQLConnection(
      "ep-snowy-cherry-a5njm8rj-pooler.us-east-2.aws.neon.tech",
      5432,
      "neondb",
      username: "neondb_owner",
      password: "npg_eEpHQvI9wkZ6",
      useSSL: true,
    );
    try {
      await connection.open();
      print("Baza povezana");
      await fetchCena();
      await fetchPoraba();
    } catch (e) {
      print("Database connection error: $e");
    }
  }


  Future<void> fetchVati() async {
    try {
      final response =
          await http.get(Uri.parse("http://192.168.0.166:3000/refresh"));
      if (response.statusCode == 200) {
        setState(() {
          vati = response.body.trim();
        });
      } else {
        print("HTTP request error: ${response.statusCode}");
      }
    } catch (e) {
      print("Napaka pri HTTP requestu: $e");
    }
  }


  Future<void> fetchCena() async {
    if (connection.isClosed) {
      print("Povezava ni odprta, fetchCena ne bo izveden.");
      return;
    }
    try {
      List<List<dynamic>> result = await connection.query(
        """
        SELECT dnevni_izracun_cena
        FROM intervali
        ORDER BY datum DESC, ura DESC
        LIMIT 1;
        """
      );
      if (result.isNotEmpty) {
        double value = double.tryParse(result.first.first.toString()) ?? 0.0;
        setState(() {
          cena = value.toStringAsFixed(10);
        });
      }
    } catch (e) {
      print("Napaka pri pridobivanju cene: $e");
    }
  }

   
  Future<void> fetchPoraba() async {
    if (connection.isClosed) {
      print("Povezava ni odprta, fetchPoraba ne bo izveden.");
      return;
    }
    try {
      List<List<dynamic>> result = await connection.query(
        """
        SELECT dnevni_izracun_poraba
        FROM intervali
        ORDER BY datum DESC, ura DESC
        LIMIT 1;
        """
      );
      if (result.isNotEmpty) {
        double value = double.tryParse(result.first.first.toString()) ?? 0.0;
        setState(() {
          poraba = value.toStringAsFixed(9);
        });
      }
    } catch (e) {
      print("Napaka pri pridobivanju dnevne porabe: $e");
    }
  }

  Future<void> fetchTarifa() async {
    if (connection.isClosed) {
      print("Povezava ni odprta, fetchCena ne bo izveden.");
      return;
    }
    try {
      List<List<dynamic>> result = await connection.query(
        """
        SELECT tarifa
        FROM intervali
        ORDER BY datum DESC, ura DESC
        LIMIT 1;
        """
      );
       if (result.isNotEmpty) {
        double value = double.tryParse(result.first.first.toString()) ?? 0.0;
        setState(() {
          tarifa = value.toStringAsFixed(2);
        });
      }
    } catch (e) {
      print("Napaka pri pridobivanju tarife: $e");
    }
  }

  @override
  void dispose() {
    connection.close();
    autoRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dnevni graf porabe',
      home: Scaffold(
        appBar: AppBar(title: const Text("Database & HTTP Test")),
        body: Column(
          children: [
   
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Poraba: $vati W",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
            ),

             Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Omreznina: $tarifa EUR",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
            ),
   
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                "Dnevna Cena: $cena €",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                "Dnevna Poraba: $poraba kWh",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
            ),
         
            Expanded(
              child: DailyConsumptionChart(connection: connection),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  fetchVati();
                  fetchCena();
                  fetchPoraba();
                  fetchTarifa();
                },
                child: const Text("Osveži"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DataPoint {
  final double time;
  final double poraba;
  DataPoint({required this.time, required this.poraba});
}


class DailyConsumptionChart extends StatefulWidget {
  final PostgreSQLConnection connection;
  const DailyConsumptionChart({Key? key, required this.connection})
      : super(key: key);

  @override
  State<DailyConsumptionChart> createState() => _DailyConsumptionChartState();
}

class _DailyConsumptionChartState extends State<DailyConsumptionChart> {
  List<DataPoint> dataPoints = [];
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    fetchData();

    refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      fetchData();
    });
  }

  Future<void> fetchData() async {
    if (widget.connection.isClosed) {
      print("Povezava ni odprta, fetchData ne bo izveden.");
      return;
    }
    try {
      print("Izvajam poizvedbo za dnevne podatke...");
      List<List<dynamic>> results = await widget.connection.query(
        """
        SELECT poraba, (ura)::text AS ura_str
        FROM intervali
        WHERE datum = CURRENT_DATE
        ORDER BY ura
        """
      );
      print("Rezultati iz baze (daily): $results");
      List<DataPoint> tempPoints = [];
      for (var row in results) {
        double value = row[0] is int
            ? (row[0] as int).toDouble()
            : (row[0] as double);
        String timeString = row[1].toString();
        List<String> parts = timeString.split(':');
        int hours = int.parse(parts[0]);
        int minutes = int.parse(parts[1]);
        double seconds = double.parse(parts[2]);
        double totalMinutes = hours * 60 + minutes + (seconds / 60);
        tempPoints.add(DataPoint(time: totalMinutes, poraba: value));
      }
      setState(() {
        dataPoints = tempPoints;
      });
    } catch (e) {
      print("Napaka pri pridobivanju dnevnih podatkov: $e");
    }
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (dataPoints.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    List<FlSpot> spots = List.generate(
      dataPoints.length,
      (index) => FlSpot(index.toDouble(), dataPoints[index].poraba),
    );

    double minX = 0;
    double maxX = dataPoints.length - 1.toDouble();
    double maxDataValue = dataPoints.map((dp) => dp.poraba).reduce(max);
    double calculatedMaxY = max(maxDataValue, 0.001) * 1.1;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: calculatedMaxY,
          minX: minX,
          maxX: maxX,
          gridData: FlGridData(show: true),
          lineTouchData: LineTouchData(enabled: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              axisNameWidget: const Text("Čas"),
              axisNameSize: 20,
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  int index = value.round();
                  int labelInterval = max(1, dataPoints.length ~/ 6);
                  if (index % labelInterval != 0 && index != dataPoints.length - 1) {
                    return const SizedBox();
                  }
                  int absMinutes = dataPoints[index].time.round();
                  int hrs = absMinutes ~/ 60;
                  int mins = absMinutes % 60;
                  return Text(
                    "${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}",
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: const Text("Poraba"),
              axisNameSize: 20,
              sideTitles: SideTitles(
                showTitles: true,
                interval: 0.0001,
                getTitlesWidget: (value, meta) {
                  if (value < 0) return const SizedBox();
                  return Text(
                    value.toStringAsFixed(4),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: 3,
              dotData: FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }
}
