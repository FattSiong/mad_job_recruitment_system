// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:geocoding/geocoding.dart'; // To get the address text
//
// class CompanyMapPicker extends StatefulWidget {
//   const CompanyMapPicker({super.key});
//
//   @override
//   State<CompanyMapPicker> createState() => _CompanyMapPickerState();
// }
//
// class _CompanyMapPickerState extends State<CompanyMapPicker> {
//   // Default to Kuala Lumpur
//   static const LatLng _initialPosition = LatLng(3.1390, 101.6869);
//
//   LatLng? _pickedLocation;
//   String _pickedAddress = 'Tap the map to select your HQ';
//   bool _isLoadingAddress = false;
//
//   // Converts the tapped coordinates into a readable address
//   Future<void> _getAddressFromLatLng(LatLng position) async {
//     setState(() => _isLoadingAddress = true);
//     try {
//       List<Placemark> placemarks = await placemarkFromCoordinates(
//         position.latitude,
//         position.longitude,
//       );
//
//       if (placemarks.isNotEmpty) {
//         Placemark place = placemarks[0];
//         setState(() {
//           _pickedAddress = '${place.street}, ${place.locality}, ${place.postalCode}, ${place.country}';
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _pickedAddress = 'Could not fetch address for this location.';
//       });
//     } finally {
//       setState(() => _isLoadingAddress = false);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Pick HQ Location'),
//         actions: [
//           // The check button to confirm the selection
//           if (_pickedLocation != null)
//             IconButton(
//               icon: const Icon(Icons.check),
//               onPressed: () {
//                 // Return the data back to the register screen
//                 Navigator.pop(context, {
//                   'latitude': _pickedLocation!.latitude,
//                   'longitude': _pickedLocation!.longitude,
//                   'address': _pickedAddress,
//                 });
//               },
//             ),
//         ],
//       ),
//       body: Stack(
//         children: [
//           GoogleMap(
//             initialCameraPosition: const CameraPosition(
//               target: _initialPosition,
//               zoom: 14,
//             ),
//             onTap: (LatLng location) {
//               setState(() {
//                 _pickedLocation = location;
//               });
//               _getAddressFromLatLng(location);
//             },
//             markers: _pickedLocation == null
//                 ? {}
//                 : {
//               Marker(
//                 markerId: const MarkerId('picked_location'),
//                 position: _pickedLocation!,
//               ),
//             },
//           ),
//
//           // A floating card at the bottom to show the address
//           Positioned(
//             bottom: 24,
//             left: 24,
//             right: 24,
//             child: Card(
//               elevation: 8,
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               child: Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: _isLoadingAddress
//                     ? const Center(child: CircularProgressIndicator())
//                     : Text(
//                   _pickedAddress,
//                   style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                   textAlign: TextAlign.center,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }