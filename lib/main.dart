import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';



void main() {  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VBAN Manager',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'VBAN Manager'),
    );
  }
}

class TabData {
  String ip = '';
  String name = '';
  String backend = 'pulseaudio';
  bool useDOption = false;
  String dValue = '';
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  late List<TabData> _tabDataList;
  late TabController _tabController;
  String _output = '';
  late Timer _timer; // Agregar esta línea para definir el temporizador

  @override
  void initState() {
    super.initState();
    _initializeTabData();
    _loadSavedData();
    _tabController = TabController(length: 2, vsync: this);
    _timer = Timer(Duration(seconds: 0), () {}); // Inicializar el temporizador
  }

  void _initializeTabData() {
    _tabDataList = List.generate(2, (index) => TabData());
  }



  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < _tabDataList.length; i++) {
      final tabData = _tabDataList[i];
      setState(() {
        tabData.ip = prefs.getString('ip$i') ?? '';
        tabData.name = prefs.getString('name$i') ?? '';
        tabData.backend = prefs.getString('backend$i') ?? 'pulseaudio';
        tabData.useDOption = prefs.getBool('useDOption$i') ?? false;
        if (tabData.useDOption) {
          tabData.dValue = prefs.getString('dValue$i') ?? '';
        }
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < _tabDataList.length; i++) {
      final tabData = _tabDataList[i];
      await prefs.setString('ip$i', tabData.ip);
      await prefs.setString('name$i', tabData.name);
      await prefs.setString('backend$i', tabData.backend);
      await prefs.setBool('useDOption$i', tabData.useDOption);
      if (tabData.useDOption) {
        await prefs.setString('dValue$i', tabData.dValue);
      }
    }
  }

  Future<void> _executeCommand(int tabIndex) async {
    final tabData = _tabDataList[tabIndex];
    String ip = tabData.ip;
    String name = tabData.name;
    String dOption = tabData.useDOption ? '-d ${tabData.dValue}' : '';
    String command =
        'vban_emitter -i $ip -p 6980 -s $name -b ${tabData.backend} -r 44100 -n 2 -c 2 $dOption';

    try {
      Process process = await Process.start(
        'bash',
        ['-c', command],
      );

      process.stdout.transform(utf8.decoder).listen((data) {
        setState(() {
          _output += data;
        });
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        setState(() {
          _output += 'Error: $data';
        });
      });
    } catch (e) {
      setState(() {
        _output = 'Error: $e';
      });
    }
  }

Future<void> _stopAllProcesses() async {
  try {
    ProcessResult result = await Process.run('pkill', ['-f', 'vban_emitter']); 
    setState(() {
      _output += 'Stopped all VBAN processes.\n';
      _timer?.cancel(); 
      _timer = Timer(Duration(seconds: 4), () { 
        setState(() {
          _output = '';
        });
      });
    });
  } catch (e) {
    setState(() {
      _output += 'Error: $e';
    });
  }
}

@override
void dispose() {
  _timer?.cancel(); 
  super.dispose();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [ // Agrega acciones a la AppBar
          IconButton(
            icon: Icon(Icons.stop), // Icono para detener procesos
            onPressed: _stopAllProcesses, // Función para detener procesos
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Proceso 1'),
            Tab(text: 'Proceso 2'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabContent(0),
          _buildTabContent(1),
        ],
      ),
    );
  }

  Widget _buildTabContent(int tabIndex) {
    final tabData = _tabDataList[tabIndex];
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
        TextField(
          controller: TextEditingController(text: tabData.ip)..selection = TextSelection.fromPosition(TextPosition(offset: tabData.ip.length)),
          decoration: const InputDecoration(
            labelText: 'IP Address',
          ),
          onChanged: (value) {
            setState(() {
              tabData.ip = value;
              _saveData();
            });
          },
        ),
          const SizedBox(height: 10),
          TextField(
            controller: TextEditingController(text: tabData.name)..selection = TextSelection.fromPosition(TextPosition(offset: tabData.name.length)),
            decoration: const InputDecoration(
              labelText: 'Stream Name',
            ),
            onChanged: (value) {
              setState(() {
                tabData.name = value;
                _saveData();
              });
            },
          ),

            const SizedBox(height: 10),
            Align(
            alignment: Alignment.centerLeft,
            child: DropdownButton<String>(
              value: tabData.backend,
              onChanged: (String? newValue) {
              setState(() {
                tabData.backend = newValue!;
                _saveData();
              });
              },
              items: <String>['alsa', 'pulseaudio', 'jack']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
              }).toList(),
            ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Checkbox(
                value: tabData.useDOption,
                onChanged: (bool? value) {
                  setState(() {
                    tabData.useDOption = value!;
                    _saveData();
                  });
                },
              ),
              const Text('Use -d Option'),
            ],
          ),
          if (tabData.useDOption)
            TextField(
              controller: TextEditingController(text: tabData.dValue)..selection = TextSelection.fromPosition(TextPosition(offset: tabData.dValue.length)),
              decoration: const InputDecoration(
                labelText: '-d Value',
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  tabData.dValue = value;
                  _saveData();
                });
              },
            ),
          const SizedBox(height: 20),
            Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              ElevatedButton(
              onPressed: () => _executeCommand(tabIndex),
              child: const Text('Execute Command'),
              ),
            ],
            ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                _output,
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
