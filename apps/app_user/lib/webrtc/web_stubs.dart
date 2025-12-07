// Stub file for non-web platforms
// This file is used when dart.library.html is not available

// Stub for AudioElement type (only used on non-web platforms)
class AudioElement {
  void pause() {}
  void remove() {}
}

// Stub for document (only used on non-web platforms)
final document = null;

// Stub namespace for js_util (only used on non-web platforms)  
class js_util {
  // Stub - not used on non-web platforms
  static void setProperty(dynamic object, String property, dynamic value) {
    // No-op on non-web platforms
  }
}
