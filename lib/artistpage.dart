// Import the dart:ui library for opacity
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'lyricPage.dart';

class ArtistDetailScreen extends StatefulWidget {
  final String artistId;
  final String artistName;

  ArtistDetailScreen({required this.artistId, required this.artistName});

  @override
  _ArtistDetailScreenState createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  Map<String, dynamic>? _artistDetails;
  List<Map<String, dynamic>> _topTracks = [];
  bool _isLoading = true;

  Future<String?> _getSpotifyAccessToken() async {
    const clientId = 'ebd43e8a6ea744019a931a1218658070';
    const clientSecret = 'cefb61a6dbb443ae9e162b95dcc0b425';

    final String credentials = base64Encode(utf8.encode('$clientId:$clientSecret'));

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

  Future<void> _fetchArtistDetails() async {
    final accessToken = await _getSpotifyAccessToken();
    if (accessToken == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final artistResponse = await http.get(
        Uri.parse('https://api.spotify.com/v1/artists/${widget.artistId}'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      final tracksResponse = await http.get(
        Uri.parse('https://api.spotify.com/v1/artists/${widget.artistId}/top-tracks?market=US'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (artistResponse.statusCode == 200 && tracksResponse.statusCode == 200) {
        final artistData = json.decode(artistResponse.body);
        final tracksData = json.decode(tracksResponse.body);

        setState(() {
          _artistDetails = artistData;
          _topTracks = (tracksData['tracks'] as List).map((track) {
            return {
              'name': track['name'],
              'previewUrl': track['preview_url'],
              'albumImage': track['album']['images'].isNotEmpty
                  ? track['album']['images'][0]['url']
                  : null,
            };
          }).toList();
          _isLoading = false;
        });
      } else {
        if (artistResponse.statusCode == 429 || tracksResponse.statusCode == 429) {
          print('Rate limit exceeded. Please try again later.');
        } else {
          print('Failed to fetch artist data: ${artistResponse.statusCode}, ${tracksResponse.statusCode}');
        }
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching artist details: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchArtistDetails();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.artistName, style: TextStyle(color: Colors.white)),
        // Make the back arrow white
        iconTheme: IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.white))
          : _artistDetails == null
          ? Center(
        child: Text(
          'Failed to load artist details. Please try again.',
          style: TextStyle(color: Colors.white),
        ),
      )
          : Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.network(
              _artistDetails!['images'][0]['url'],
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.3),
              colorBlendMode: BlendMode.darken,
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.all(16.0),
            child: ListView(
              children: [
                // Artist Name
                Text(
                  _artistDetails!['name'],
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                // Genres and Popularity in a Wrap
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16.0,
                  runSpacing: 8.0,
                  children: [
                    // Genres
                    if (_artistDetails!['genres'] != null &&
                        _artistDetails!['genres'].isNotEmpty)
                      Text(
                        'Genres: ${_artistDetails!['genres'].join(', ')}',
                        style: TextStyle(color: Colors.white70),
                      ),
                    // Popularity
                    if (_artistDetails!['popularity'] != null)
                      Text(
                        'Popularity: ${_artistDetails!['popularity']}%',
                        style: TextStyle(color: Colors.white70),
                      ),
                  ],
                ),
                SizedBox(height: 24),
                // Top Tracks Header
                Text(
                  'Top Tracks:',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                // Top Tracks List
                if (_topTracks.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _topTracks.length,
                    itemBuilder: (context, index) {
                      final track = _topTracks[index];
                      return Card(
                        // Change color to semi-transparent black
                        color: Colors.black.withOpacity(0.8),
                        margin: EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          leading: track['albumImage'] != null
                              ? Image.network(
                            track['albumImage'],
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          )
                              : Icon(Icons.music_note,
                              color: Colors.white70, size: 50),
                          title: Text(
                            track['name'],
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            widget.artistName,
                            style: TextStyle(color: Colors.white70),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LyricPage(
                                  songName: track['name'],
                                  artistName: widget.artistName,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  )
                else
                  Text(
                    'No top tracks available.',
                    style: TextStyle(color: Colors.white70),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
