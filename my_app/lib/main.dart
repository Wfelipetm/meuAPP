import 'dart:async';
import 'location_database.dart';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(LocationDatabase()),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final LocationDatabase locationDatabase;

  HomeScreen(this.locationDatabase);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Position> _positionList = [];
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    // Inicializa um temporizador para chamar _getCurrentLocation a cada minuto
    _timer = Timer.periodic(
        Duration(minutes: 1), (Timer t) => _getCurrentLocation());
  }

  @override
  void dispose() {
    // Cancela o temporizador para evitar vazamentos de memória
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Localização do Dispositivo'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_positionList.isNotEmpty)
              Column(
                children: _positionList
                    .map((position) => Text(
                          'Latitude: ${position.latitude}\nLongitude: ${position.longitude}',
                          style: TextStyle(fontSize: 18),
                          textAlign: TextAlign.center,
                        ))
                    .toList(),
              ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _getLocationPermission();
              },
              child: Text('Obter Localização Atual'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _navigateToDatabaseViewer(context);
              },
              child: Text('Ver Informações Salvas'),
            ),
          ],
        ),
      ),
    );
  }

  // Método para obter a localização atual
  _getCurrentLocation() async {
    try {
      print('Obtendo localização atual...');
      // Usa o pacote Geolocator para obter a posição atual do dispositivo
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      print('Localização obtida: $position');

      // Atualiza a interface com a nova posição
      setState(() {
        _positionList.add(position);
      });

      // Salva a localização obtida no banco de dados
      widget.locationDatabase.insertLocation(
        position.latitude,
        position.longitude,
      );
      print('Localização salva no banco de dados.');
    } catch (e) {
      print('Erro ao obter ou salvar a localização: $e');
    }
  }

  // Método para solicitar permissão de localização
  _getLocationPermission() async {
    var status = await Permission.location.request();

    if (status.isGranted) {
      // Se a permissão for concedida, obtém a localização atual
      _getCurrentLocation();
    } else {
      print('Permissão de localização negada');
    }
  }

  // Método para navegar para a tela de visualização do banco de dados
  _navigateToDatabaseViewer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => DatabaseViewer(widget.locationDatabase)),
    );
  }
}

class LocationDatabase {
  static Database? _database;
  static const String tableName = 'locations';

  // Getter para a instância do banco de dados
  Future<Database> get database async {
    if (_database != null) return _database!;

    // Se a instância do banco de dados não foi criada, a inicializa
    _database = await initDatabase();
    return _database!;
  }

  // Método para inicializar o banco de dados
  Future<Database> initDatabase() async {
    // Obtém o caminho para o arquivo do banco de dados
    String documentsDirectory = await getDatabasesPath();
    String path = join(documentsDirectory, 'locations.db');

    // Abre ou cria o banco de dados
    return await openDatabase(path, version: 1, onCreate: (db, version) async {
      // Cria a tabela 'locations' se ela não existir
      await db.execute('''
        CREATE TABLE $tableName (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          latitude REAL,
          longitude REAL,
          timestamp TEXT
        )
      ''');
    });
  }

  // Método para inserir uma localização no banco de dados
  Future<void> insertLocation(double latitude, double longitude) async {
    final Database db = await database;

    try {
      // Insere a localização com latitude, longitude e timestamp
      await db.insert(
        tableName,
        {
          'latitude': latitude,
          'longitude': longitude,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      print('Inserção no banco de dados bem-sucedida.');
    } catch (e) {
      print('Erro ao inserir no banco de dados: $e');
    }
  }

  // Método para recuperar todas as localizações do banco de dados
  Future<List<Map<String, dynamic>>> getLocations() async {
    final Database db = await database;
    return db.query(tableName);
  }
}

class DatabaseViewer extends StatelessWidget {
  final LocationDatabase locationDatabase;

  DatabaseViewer(this.locationDatabase);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Informações Salvas no Banco de Dados'),
      ),
      body: FutureBuilder(
        // FutureBuilder para carregar dados assincronamente do banco de dados
        future: locationDatabase.getLocations(),
        builder: (context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasData) {
              // Se houver dados, exibe-os em um ListView
              List<Map<String, dynamic>> data = snapshot.data!;
              return ListView.builder(
                itemCount: data.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text('Latitude: ${data[index]['latitude']}'),
                    subtitle: Text('Longitude: ${data[index]['longitude']}'),
                  );
                },
              );
            } else {
              // Se não houver dados, exibe uma mensagem
              return Center(
                child: Text('Nenhuma informação salva.'),
              );
            }
          } else {
            // Enquanto os dados ainda estão carregando, exibe um indicador de carregamento
            return Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
    );
  }
}
