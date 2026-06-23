import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

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
  // 預設地圖中心：台北（GPS 關閉或權限拒絕時才用這個）
  static const _defaultCenter = LatLng(25.0330, 121.5654);

  LatLng? _picked;       // 目前選到的點
  String? _address;      // 轉出來的地址文字
  bool _looking = false; // 是否正在查地址
  bool _locating = false; // 是否正在取得 GPS 位置

  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      // 有舊位置（重新選擇）：停在舊位置，不去問 GPS
      _picked = LatLng(widget.initialLat!, widget.initialLng!);
      _reverseGeocode(_picked!);
    } else {
      // 沒有舊位置（全新選擇）：嘗試定位到目前位置
      _goToCurrentLocation();
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // 取得目前 GPS 位置，移動地圖過去
  Future<void> _goToCurrentLocation() async {
    setState(() => _locating = true);
    try {
      // 第一步：確認裝置的定位服務（GPS）是否開啟
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // GPS 關閉 → 停在台北預設位置，不跳錯誤（使用者可能就是不想開）
        return;
      }

      // 第二步：確認或請求定位權限
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // 還沒問過 → 跳出系統權限視窗問使用者
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // 使用者按拒絕 → 停在台北，不強迫
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        // 使用者選了「永遠拒絕」→ 停在台北
        return;
      }

      // 第三步：取得目前座標
      // accuracy 設 low 是為了讓定位更快，對選地點來說精度夠用
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );

      final current = LatLng(pos.latitude, pos.longitude);

      // 第四步：把地圖移動到目前位置，並插針
      // addPostFrameCallback 是確保地圖畫面已經建立完成後再移動
      // 如果直接在 initState 裡移動，地圖還沒建好會出錯
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(current, 15);
        }
      });

      setState(() => _picked = current);
      await _reverseGeocode(current);
    } catch (_) {
      // 任何意外錯誤（例如定位逾時）→ 靜默失敗，停在台北
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // 使用者在地圖上點了某個點
  Future<void> _onTap(TapPosition _, LatLng pos) async {
    setState(() => _picked = pos);
    await _reverseGeocode(pos);
  }

  // 把經緯度轉成看得懂的地址文字
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
      _address = null;
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
            onTap: _onTap,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.flutter_application_1',
            ),
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

        // ── 正在定位中的提示 ──────────────────────────────
        if (_locating)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('正在取得目前位置…'),
                ]),
              ),
            ),
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