/// Neuralis — Audio Engine / Domain
/// Predisposizione per l'integrazione con servizi di metadati musicali.
///
/// Posizione: lib/features/audio_engine/domain/metadata_repository.dart
library;

// ---------------------------------------------------------------------------
// TrackMetadata — entità per i metadati del brano corrente
// ---------------------------------------------------------------------------

/// Metadati del brano musicale attualmente in riproduzione.
///
/// Popolato in futuro tramite Spotify Web API o Last.fm API.
// TODO(future): arricchire con: albumArt (Uri), durationMs, progressMs
class TrackMetadata {
  const TrackMetadata({
    required this.title,
    required this.artist,
    this.album,
    this.albumArtUrl,
  });

  /// Titolo del brano.
  final String title;

  /// Nome dell'artista o del gruppo.
  final String artist;

  /// Nome dell'album (opzionale).
  final String? album;

  /// URL dell'immagine di copertina (opzionale).
  // TODO(future): da visualizzare nell'overlay LCARS come thumbnail
  final String? albumArtUrl;

  @override
  String toString() => 'TrackMetadata("$title" by $artist)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackMetadata &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          artist == other.artist &&
          album == other.album &&
          albumArtUrl == other.albumArtUrl;

  @override
  int get hashCode => Object.hash(title, artist, album, albumArtUrl);
}

// ---------------------------------------------------------------------------
// MetadataRepository — contratto astratto (TODO future)
// ---------------------------------------------------------------------------

/// Contratto astratto per il recupero dei metadati del brano in riproduzione.
///
/// ⚠️ NON IMPLEMENTARE ORA — predisposizione per espansione futura.
///
/// Implementazioni pianificate:
///   - SpotifyMetadataRepository  → Spotify Web API (OAuth 2.0)
///   - LastFmMetadataRepository   → Last.fm Scrobbling API
///
/// Quando implementato, i metadati saranno visualizzati nell'overlay LCARS
/// come pannello informativo laterale (titolo + artista + artwork).
///
// TODO(future): implementare con Spotify Web API / Last.fm API
// TODO(future): aggiungere caching locale con TTL configurabile
// TODO(future): aggiungere supporto per Apple Music (MusicKit)
abstract class MetadataRepository {
  /// Recupera i metadati del brano attualmente in riproduzione.
  ///
  /// Restituisce null se nessun brano è in riproduzione o se
  /// l'autenticazione con il servizio non è disponibile.
  // TODO(future): implementare
  Future<TrackMetadata?> getCurrentTrackMetadata();

  /// Stream che emette i metadati aggiornati quando il brano cambia.
  ///
  /// Emette null quando la riproduzione si interrompe.
  // TODO(future): implementare con Spotify real-time polling o webhook
  Stream<TrackMetadata?> watchCurrentTrack();
}
