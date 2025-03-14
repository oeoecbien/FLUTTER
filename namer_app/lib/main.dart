import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitDown,
    DeviceOrientation.portraitUp,
  ]).then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'Namer App',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        ),
        home: const MyHomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  var current = WordPair.random();
  late List<WordPair> favorites;
  var initialized = false;

  // Convertir les favoris en JSON
  static String _wordPairsToJson(List<WordPair> favorites) {
    return json.encode(
      favorites
          .map((pair) => {'first': pair.first, 'second': pair.second})
          .toList(),
    );
  }

  // Convertir le JSON en une liste de WordPair
  static List<WordPair> _wordPairsFromJson(String jsonStr) {
    final List<dynamic> list = json.decode(jsonStr);
    return list.map((item) => WordPair(item['first'], item['second'])).toList();
  }

  // Initialisation des favoris
  Future<void> init() async {
    if (initialized) {
      return;
    }

    final storage = await SharedPreferences.getInstance();
    final data = storage.getString('favorites');

    if (data == null) {
      favorites = <WordPair>[];
    } else {
      favorites = _wordPairsFromJson(data);
    }

    initialized = true;
  }

  // Sauvegarder les favoris dans SharedPreferences
  Future<bool> _saveToStorage() async {
    var storage = await SharedPreferences.getInstance();
    return await storage.setString('favorites', _wordPairsToJson(favorites));
  }

  void getNext() {
    current = WordPair.random();
    notifyListeners();
  }

  void toggleFavorite() {
    if (favorites.contains(current)) {
      favorites.remove(current);
    } else {
      favorites.add(current);
    }
    _saveToStorage(); // Sauvegarde après modification
    notifyListeners();
  }

  void removeFavorite(WordPair pair) {
    favorites.remove(pair);
    _saveToStorage(); // Sauvegarde après suppression
    notifyListeners();
  }
}

class GeneratorPage extends StatelessWidget {
  const GeneratorPage({super.key});

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    var pair = appState.current;

    IconData icon;
    if (appState.favorites.contains(pair)) {
      icon = Icons.favorite;
    } else {
      icon = Icons.favorite_border;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BigCard(pair: pair),
          const SizedBox(height: 10.0),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  appState.toggleFavorite();
                },
                icon: Icon(icon),
                label: const Text("J'aime"),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  appState.getNext();
                },
                child: const Text('Suivant'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;
  Future<void>? initializer;

  @override
  void initState() {
    super.initState();
    var appState = context.read<MyAppState>();
    initializer = appState.init(); // Initialisation des favoris au démarrage
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: initializer,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child:
                  CircularProgressIndicator(), // Afficher un indicateur de chargement
            ),
          );
        }

        // Lorsque l'initialisation est terminée, afficher la page en fonction de l'index sélectionné
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 600) {
              return Scaffold(
                body: SafeArea(
                  child: Row(
                    children: [
                      NavigationRail(
                        selectedIndex: selectedIndex,
                        onDestinationSelected: (index) {
                          setState(() {
                            selectedIndex = index;
                          });
                        },
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(Icons.home),
                            label: Text('Accueil'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.favorite),
                            label: Text('Favoris'),
                          ),
                        ],
                      ),
                      Expanded(child: _getPage(selectedIndex)),
                    ],
                  ),
                ),
              );
            } else {
              return Scaffold(
                body: _getPage(selectedIndex),
                bottomNavigationBar: BottomNavigationBar(
                  items: const [
                    BottomNavigationBarItem(
                        icon: Icon(Icons.home), label: 'Accueil'),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.favorite), label: 'Favoris'),
                  ],
                  currentIndex: selectedIndex,
                  onTap: (value) {
                    setState(() {
                      selectedIndex = value;
                    });
                  },
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return const GeneratorPage();
      case 1:
        return const FavoritesPage();
      default:
        return const GeneratorPage();
    }
  }
}

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    if (appState.favorites.isEmpty) {
      return const Center(child: Text("Aucun favori enregistré."));
    }

    return ListView(
      children: [
        for (var pair in appState.favorites)
          ListTile(
            leading: const Icon(Icons.favorite),
            title: Text(pair.asPascalCase),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                appState.removeFavorite(pair);
              },
            ),
          ),
      ],
    );
  }
}

class BigCard extends StatelessWidget {
  const BigCard({
    super.key,
    required this.pair,
  });

  final WordPair pair;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );

    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(
          pair.asLowerCase,
          style: style,
          semanticsLabel: pair.asPascalCase,
        ),
      ),
    );
  }
}
