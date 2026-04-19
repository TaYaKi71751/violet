import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart';
import 'package:violet/network/wrapper.dart' as http;

class HttpCacheManager extends HttpFileService {
  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    // Use your wrapper here
    final response = await http.get(url, headers: headers);
    return HttpGetResponse(
      StreamedResponse(
        Stream.value(response.bodyBytes),
        response.statusCode,
        contentLength: response.bodyBytes.length,
        headers: response.headers,
        request: Request('GET', Uri.parse(url)),
      ),
    );
  }
}

class WrapperCacheManager extends CacheManager {
  static const key = 'httpCache';

  WrapperCacheManager() : super(Config(key, fileService: HttpCacheManager()));
}
