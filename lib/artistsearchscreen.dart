import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'ArtistPage.dart'; // <-- Your existing ArtistDetailScreen file

// Replace these with your actual Client ID and Secret
const String clientId = 'ebd43e8a6ea744019a931a1218658070';
const String clientSecret = 'cefb61a6dbb443ae9e162b95dcc0b425';

class ArtistSearchScreen extends StatefulWidget {
  @override
  _ArtistSearchScreenState createState() => _ArtistSearchScreenState();
}

class _ArtistSearchScreenState extends State<ArtistSearchScreen> {
  final TextEditingController _controller = TextEditingController();

  /// Holds results from searching an artist by name
  List<Map<String, dynamic>> _searchResults = [];

  bool _isLoading = false;

  /// Retrieve a fresh Spotify token using Client Credentials Flow
  Future<String?> _getSpotifyAccessToken() async {
    final String credentials =
    base64Encode(utf8.encode('$clientId:$clientSecret'));

    final response = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {
        'Authorization': 'Basic $credentials',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'client_credentials',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return data['access_token'];
    } else {
      print('Failed to get access token: ${response.statusCode}');
      return null;
    }
  }

  /// Searches Spotify for an artist by name and stores the results in [_searchResults].
  Future<void> _searchArtists(String artistName) async {
    if (artistName.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);

    final accessToken = await _getSpotifyAccessToken();
    if (accessToken == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final artistResponse = await http.get(
        Uri.parse('https://api.spotify.com/v1/search?q=$artistName&type=artist&limit=10'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (artistResponse.statusCode == 200) {
        final Map<String, dynamic> artistData = json.decode(artistResponse.body);
        final List<dynamic> artists = artistData['artists']['items'];

        setState(() {
          _searchResults = artists.map((artist) {
            return {
              'name': artist['name'],
              'image': (artist['images'] != null && artist['images'].isNotEmpty)
                  ? artist['images'][0]['url']
                  : null,
              'id': artist['id'],
            };
          }).toList();
        });
      } else {
        print('Error fetching artist info: ${artistResponse.statusCode}');
      }
    } catch (e) {
      print('Error searching artists: $e');
    }

    setState(() => _isLoading = false);
  }

  void _onArtistTap(Map<String, dynamic> artist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArtistDetailScreen(
          artistId: artist['id'],
          artistName: artist['name'],
        ),
      ),
    );
    print('Artist tapped: ${artist['name']}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 1) Logo
              Padding(
                padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 300,
                ),
              ),

              // 2) Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _controller,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search, color: Colors.white70),
                    hintText: 'Search artists...',
                    hintStyle: TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.grey[850],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    if (value.isEmpty) {
                      // Clear search results if text is cleared
                      setState(() => _searchResults = []);
                    } else {
                      _searchArtists(value);
                    }
                  },
                ),
              ),

              SizedBox(height: 20),

              // 3) Loading Indicator (if searching)
              if (_isLoading)
                Center(child: CircularProgressIndicator(color: Colors.white)),

              // 4) Grid of artists (search results)
              if (!_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _searchResults.isEmpty
                      ? Text(
                    'No results found.',
                    style: TextStyle(color: Colors.white54),
                  )
                      : GridView.builder(
                    itemCount: _searchResults.length,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, // 2 columns per row
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.75,
                    ),
                    itemBuilder: (context, index) {
                      final artist = _searchResults[index];
                      return GestureDetector(
                        onTap: () => _onArtistTap(artist),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Artist Image
                              ClipOval(
                                child: (artist['image'] != null)
                                    ? Image.network(
                                  artist['image'],
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                )
                                    : Icon(
                                  Icons.person,
                                  size: 80,
                                  color: Colors.white70,
                                ),
                              ),
                              SizedBox(height: 8),
                              // Artist Name
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(
                                  artist['name'] ?? 'Unknown',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
