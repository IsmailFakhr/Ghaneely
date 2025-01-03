import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:html/parser.dart' show parse;

class LyricPage extends StatefulWidget {
  final String songName;
  final String artistName;

  LyricPage({required this.songName, required this.artistName});

  @override
  _LyricPageState createState() => _LyricPageState();
}

class _LyricPageState extends State<LyricPage> {
  String? _lyrics;
  bool _isLoading = true;
  String? _errorMessage;

  /// URL for the song’s icon from Genius
  String? _songArtImageUrl;

  // Genius API token
  static const String _accessToken =
      'JLfpifFLEaZvUamGoZHFZbfLp74TQ8b8T9EymEmzGQs4zfchMjYK0zDcjwcsxs4I';

  // Swear words for censorship
  final List<String> _swearWords = [
    "fuck", "shit", "motherfucker", "bitch", "bitches",
    "fucking", "fucks", "motherfucking", "motherfuckin'", "fuckin'", "bitchin'", "cunt",
  ];

  /// Censor any swear words in the lyrics by replacing them with asterisks.
  String _censorLyrics(String lyrics) {
    for (var word in _swearWords) {
      final censor = '*' * word.length;
      // Use a case-insensitive regex that respects word boundaries (\b).
      lyrics = lyrics.replaceAll(
        RegExp(r'\b' + word + r'\b', caseSensitive: false),
        censor,
      );
    }
    return lyrics;
  }

  /// Extracts text from HTML while preserving line breaks.
  /// For example, replace <br>, </p>, and </div> with '\n'.
  String _extractTextPreservingLineBreaks(element) {
    // Convert <br>, </p>, and </div> to newlines
    String html = element.innerHtml
        .replaceAll('<br>', '\n')
        .replaceAll('</p>', '\n')
        .replaceAll('</div>', '\n');

    // Parse the updated HTML to strip out tags but keep line breaks
    final parsed = parse(html);
    final rawText = parsed.body?.text ?? '';

    // Replace multiple spaces with a single space
    return rawText.replaceAll(RegExp(r' +'), ' ').trim();
  }

  Future<void> _fetchLyrics() async {
    try {
      print('Starting lyrics fetch for ${widget.artistName} - ${widget.songName}');

      // 1) Search for the song on Genius
      final searchUrl = Uri.parse(
        'https://api.genius.com/search?q=${Uri.encodeComponent("${widget.artistName} ${widget.songName}")}',
      );

      final searchResponse = await http.get(
        searchUrl,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Accept': 'application/json',
        },
      );

      if (searchResponse.statusCode != 200) {
        throw Exception('Search failed with status ${searchResponse.statusCode}');
      }

      final searchData = json.decode(searchResponse.body);
      final hits = searchData['response']['hits'] as List;

      if (hits.isEmpty) {
        throw Exception('No results found for this song');
      }

      // 2) Extract the first song's info
      final firstHit = hits[0]['result'];

      // Genius page for scraping lyrics
      final songUrl = firstHit['url'];
      // URL to the song’s icon (album cover) from Genius
      _songArtImageUrl = firstHit['song_art_image_url'] ?? null;

      print('Found song URL: $songUrl');
      print('Found song art image URL: $_songArtImageUrl');

      // 3) Fetch the lyrics page HTML
      final lyricsResponse = await http.get(Uri.parse(songUrl));
      if (lyricsResponse.statusCode != 200) {
        throw Exception('Failed to fetch lyrics page');
      }

      // 4) Parse the HTML for lyrics
      final document = parse(lyricsResponse.body);
      String lyricsText = '';

      // 4a) Attempt data-lyrics-container
      final dataLyricsContainers =
      document.querySelectorAll('[data-lyrics-container="true"]');
      if (dataLyricsContainers.isNotEmpty) {
        final buffers = dataLyricsContainers.map(
              (element) => _extractTextPreservingLineBreaks(element),
        );
        lyricsText = buffers.join('\n\n').trim();
      }

      // 4b) If still empty, try Lyrics__Container
      if (lyricsText.isEmpty) {
        final lyricsContainers = document.getElementsByClassName('Lyrics__Container');
        if (lyricsContainers.isNotEmpty) {
          final buffers = lyricsContainers.map(
                (element) => _extractTextPreservingLineBreaks(element),
          );
          lyricsText = buffers.join('\n\n').trim();
        }
      }

      // 4c) If still empty, try the legacy .lyrics div
      if (lyricsText.isEmpty) {
        final lyricsDiv = document.querySelector('.lyrics');
        if (lyricsDiv != null) {
          lyricsText = _extractTextPreservingLineBreaks(lyricsDiv).trim();
        }
      }

      if (lyricsText.isEmpty) {
        throw Exception('No lyrics found on page');
      }

      // 5) Clean up lyrics (remove bracketed e.g. [Chorus])
      lyricsText = lyricsText
          .replaceAll(RegExp(r'\[.*?\]'), '')         // remove [Chorus], [Verse 1], etc.
          .replaceAll(RegExp(r'(\r?\n){3,}'), '\n\n') // avoid excessive blank lines
          .trim();

      // 6) Censor any swear words before setting state
      lyricsText = _censorLyrics(lyricsText);

      // 7) Update state
      setState(() {
        _lyrics = lyricsText;
        _isLoading = false;
      });
    } catch (e) {
      print('Error in _fetchLyrics: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchLyrics();
  }

  @override
  Widget build(BuildContext context) {
    // We'll build a Stack so we can place the background image behind everything
    return Scaffold(
      body: Stack(
        children: [
          // 1) Background image (song icon) if available
          if (_songArtImageUrl != null)
            SizedBox.expand(
              child: Image.network(
                _songArtImageUrl!,
                fit: BoxFit.cover, // cover the screen, cropping if necessary
              ),
            )
          else
          // Fallback if no image found
            Container(color: Colors.black),

          // 2) Dark overlay to make text more readable
          Container(
            color: Colors.black.withOpacity(0.5),
          ),

          // 3) Main content (back arrow + title + lyrics)
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row with back arrow & song title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      // Song Title
                      Expanded(
                        child: Text(
                          '${widget.songName}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Expanded area to hold lyrics (or loading/error)
                Expanded(
                  child: _buildLyricsContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Helper to build the lyrics or error/loading widget.
  Widget _buildLyricsContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    } else if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Text(
          _lyrics ?? 'No lyrics available',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            height: 1.5,
          ),
        ),
      );
    }
  }
}
