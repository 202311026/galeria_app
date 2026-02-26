import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

void main() {
  runApp(const GaleriaApp());
}

class GaleriaApp extends StatelessWidget {
  const GaleriaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Galería',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const GaleriaScreen(),
    );
  }
}

// ─────────────────────────────────────────────
// SCREEN 1: GALERÍA
// ─────────────────────────────────────────────
class GaleriaScreen extends StatefulWidget {
  const GaleriaScreen({super.key});

  @override
  State<GaleriaScreen> createState() => _GaleriaScreenState();
}

enum EstadoGaleria { cargando, sinFotos, error, ok }

class _GaleriaScreenState extends State<GaleriaScreen> {
  EstadoGaleria _estado = EstadoGaleria.cargando;
  List<AssetEntity> _fotos = [];
  String _mensajeError = '';

  @override
  void initState() {
    super.initState();
    _cargarFotos();
  }

  Future<void> _cargarFotos() async {
    setState(() => _estado = EstadoGaleria.cargando);

    // Solicitar permiso
    final PermissionState permiso = await PhotoManager.requestPermissionExtend();

    if (!permiso.isAuth && !permiso.hasAccess) {
      setState(() {
        _estado = EstadoGaleria.error;
        _mensajeError = 'Permiso denegado.\nVe a Ajustes y permite el acceso a fotos.';
      });
      return;
    }

    try {
      // Obtener álbumes de fotos
      final List<AssetPathEntity> albumes = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );

      if (albumes.isEmpty) {
        setState(() => _estado = EstadoGaleria.sinFotos);
        return;
      }

      // Obtener todas las fotos del álbum principal
      final album = albumes.first;
      final int total = await album.assetCountAsync;

      if (total == 0) {
        setState(() => _estado = EstadoGaleria.sinFotos);
        return;
      }

      final List<AssetEntity> fotos = await album.getAssetListRange(
        start: 0,
        end: total.clamp(0, 500), // máximo 500 fotos
      );

      setState(() {
        _fotos = fotos;
        _estado = EstadoGaleria.ok;
      });
    } catch (e) {
      setState(() {
        _estado = EstadoGaleria.error;
        _mensajeError = 'Error al cargar fotos: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Galería'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarFotos,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: _construirCuerpo(),
    );
  }

  Widget _construirCuerpo() {
    switch (_estado) {
      case EstadoGaleria.cargando:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Cargando fotos...', style: TextStyle(fontSize: 16)),
            ],
          ),
        );

      case EstadoGaleria.sinFotos:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_library_outlined, size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No hay fotos en el dispositivo',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
        );

      case EstadoGaleria.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 80, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  _mensajeError,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _cargarFotos,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => PhotoManager.openSetting(),
                  child: const Text('Abrir Ajustes'),
                ),
              ],
            ),
          ),
        );

      case EstadoGaleria.ok:
        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: _fotos.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () => _abrirVisor(index),
              child: _Miniatura(asset: _fotos[index]),
            );
          },
        );
    }
  }

  void _abrirVisor(int indiceInicial) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisorScreen(
          fotos: _fotos,
          indiceInicial: indiceInicial,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// WIDGET: MINIATURA
// ─────────────────────────────────────────────
class _Miniatura extends StatefulWidget {
  final AssetEntity asset;
  const _Miniatura({required this.asset});

  @override
  State<_Miniatura> createState() => _MiniaturaState();
}

class _MiniaturaState extends State<_Miniatura> {
  late Future<dynamic> _thumbFuture;

  @override
  void initState() {
    super.initState();
    _thumbFuture = widget.asset.thumbnailDataWithSize(
      const ThumbnailSize(200, 200),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _thumbFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done || snapshot.data == null) {
          return Container(
            color: Colors.grey[300],
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// SCREEN 2: VISOR
// ─────────────────────────────────────────────
class VisorScreen extends StatefulWidget {
  final List<AssetEntity> fotos;
  final int indiceInicial;

  const VisorScreen({
    super.key,
    required this.fotos,
    required this.indiceInicial,
  });

  @override
  State<VisorScreen> createState() => _VisorScreenState();
}

class _VisorScreenState extends State<VisorScreen> {
  late PageController _pageController;
  late int _indiceActual;

  @override
  void initState() {
    super.initState();
    _indiceActual = widget.indiceInicial;
    _pageController = PageController(initialPage: widget.indiceInicial);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_indiceActual + 1} / ${widget.fotos.length}',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.fotos.length,
        onPageChanged: (i) => setState(() => _indiceActual = i),
        itemBuilder: (context, index) {
          return _FotoCompleta(asset: widget.fotos[index]);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// WIDGET: FOTO A PANTALLA COMPLETA
// ─────────────────────────────────────────────
class _FotoCompleta extends StatefulWidget {
  final AssetEntity asset;
  const _FotoCompleta({required this.asset});

  @override
  State<_FotoCompleta> createState() => _FotoCompletaState();
}

class _FotoCompletaState extends State<_FotoCompleta> {
  late Future<dynamic> _fotoFuture;

  @override
  void initState() {
    super.initState();
    _fotoFuture = widget.asset.file;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _fotoFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        if (snapshot.data == null) {
          return const Center(
            child: Icon(Icons.broken_image, color: Colors.white, size: 64),
          );
        }
        return InteractiveViewer(
          child: Center(
            child: Image.file(
              snapshot.data!,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }
}