import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';

// 在 OpenStreetMap 上點一下來選位置。
// 回傳給上一頁的格式：{ 'latitude': double, 'longitude': double, 'address': String? }
class LocationPickerPage extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  const LocationPickerPage({super.key, this.initialLat, this.initialLng});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  // 預設地圖中心：台北（沒有舊位置時，先把地圖停在這裡）
  static const _defaultCenter = LatLng(25.0330, 121.5654);

  LatLng? _picked;   // 目前選到的點
  String? _address;  // 轉出來的地址文字
  bool _looking = false; // 是否正在查地址

  // flutter_map 需要一個 controller 來控制地圖
  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    // 如果是「重新選擇」，先把舊位置帶進來
    if (widget.initialLat != null && widget.initialLng != null) {
      _picked = LatLng(widget.initialLat!, widget.initialLng!);
      _reverseGeocode(_picked!);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // 使用者在地圖上點了某個點
  Future<void> _onTap(TapPosition _, LatLng pos) async {
    setState(() => _picked = pos);
    await _reverseGeocode(pos);
  }

  // 把經緯度轉成看得懂的地址文字
  // 用手機系統內建的地理編碼，不需要任何金鑰；查不到也沒關係
  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _looking = true);
    try {
      final placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [
          p.street,
          p.subLocality,
          p.locality,
          p.administrativeArea
        ].where((s) => s != null && s.isNotEmpty).toList();
        _address = parts.join(' ');
      }
    } catch (_) {
      _address = null; // 查不到沒關係，至少還有經緯度
    } finally {
      if (mounted) setState(() => _looking = false);
    }
  }

  void _confirm() {
    if (_picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先在地圖上點一個位置')),
      );
      return;
    }
    Navigator.pop(context, {
      'latitude': _picked!.latitude,
      'longitude': _picked!.longitude,
      'address': _address,
    });
  }

  @override
  Widget build(BuildContext context) {
    final center = _picked ?? _defaultCenter;
    return Scaffold(
      appBar: AppBar(
        title: const Text('選擇位置'),
        backgroundColor: const Color(0xFF2E7D9F),
        foregroundColor: Colors.white,
      ),
      body: Stack(children: [
        // ── 地圖本體 ──────────────────────────────────────
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 15,
            onTap: _onTap, // 點地圖就呼叫 _onTap
          ),
          children: [
            // 地圖圖磚來自 OpenStreetMap，免費、不需金鑰
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.app', // 換成你的套件名稱
            ),
            // 有選到點才顯示針
            if (_picked != null)
              MarkerLayer(markers: [
                Marker(
                  point: _picked!,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.place,
                    color: Color(0xFF2E7D9F),
                    size: 40,
                  ),
                ),
              ]),
          ],
        ),

        // ── 底部資訊條：地址 + 確定按鈕 ──────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Icon(Icons.place, color: Color(0xFF2E7D9F)),
                const SizedBox(width: 8),
                Expanded(
                  child: _picked == null
                      ? const Text('在地圖上點一下來選擇位置')
                      : Text(_looking
                          ? '查詢地址中…'
                          : (_address ?? '已選擇位置')),
                ),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D9F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _confirm,
                  child: const Text('確定使用這個位置'),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}