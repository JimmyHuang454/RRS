import 'dart:io';
import 'dart:typed_data';

import 'package:http2/http2.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/utils/utils.dart';

Map<String, Map<String, dynamic>> liveConnection = {};

class H2Socket {
  dynamic transportStream;

  H2Socket({required this.transportStream});

  void add(List<int> data) {
    if (transportStream is ClientTransportStream) {
      (transportStream as ClientTransportStream).sendData(data);
    } else if (transportStream is ServerTransportStream) {
      (transportStream as ServerTransportStream).sendData(data);
    }
  }

  void listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone}) {
    if (transportStream is ClientTransportStream) {
      (transportStream as ClientTransportStream).incomingMessages.listen(
          (event) {
        if (event is DataStreamMessage) {
          onData!(Uint8List.fromList(event.bytes));
        }
      }, onError: onError, onDone: onDone, cancelOnError: true);
    } else if (transportStream is ServerTransportStream) {
      (transportStream as ServerTransportStream).incomingMessages.listen(
          (event) {
        if (event is DataStreamMessage) {
          onData!(Uint8List.fromList(event.bytes));
        }
      }, onError: onError, onDone: onDone, cancelOnError: true);
    }
  }

  void close() {
    if (transportStream is ClientTransportStream) {
      (transportStream as ClientTransportStream).outgoingMessages.close();
    } else if (transportStream is ServerTransportStream) {
      (transportStream as ServerTransportStream).outgoingMessages.close();
    }
  }

  Future<dynamic> get done => transportStream.outgoingMessages.done;
}

class H2Request extends TransportClient1 {
  String hostAndPort = '';
  String path = '';
  int muxID = 0;

  late Uri uri;
  late ClientTransportConnection con;
  late ClientTransportStream clientTransportStream;
  late Map<String, dynamic> info;
  late List<Header> header;

  H2Request({required super.config}) : super(protocolName: 'h2') {
    path = getValue(config, 'setting.path', '');

    header = [
      Header.ascii(':method', 'GET'),
      Header.ascii(':path', uri.path),
      Header.ascii(':scheme', uri.scheme),
      Header.ascii(':authority', uri.host),
    ];
  }

  Future<void> _connect() async {
    if (!liveConnection.containsKey(hostAndPort)) {
      liveConnection[hostAndPort] = {};
    }
    Map<String, dynamic> info;
    info = {};

    liveConnection[hostAndPort]!.forEach(
      (key, value) {
        if (!value['isClosed']) {
          info = value;
        }
      },
    );

    if (info == {}) {
      dynamic s;
      muxID += 1;
      if (uri.scheme.startsWith('https')) {
        s = await SecureSocket.connect(
          uri.host,
          uri.port,
          supportedProtocols: ['h2'],
        );
      } else {
        s = await Socket.connect(
          uri.host,
          uri.port,
        );
      }
      con = ClientTransportConnection.viaSocket(s);
      info = {'con': con, 'link': 1, 'isClosed': false};
      liveConnection[hostAndPort] = info;
    }
    info['link'] += 1;
    con = info['con'];
  }

  @override
  Future<RRSSocket> connect(host, int port) async {
    var address = '';
    if (port == 443 || port == 80) {
      address = '$host/$path';
    } else {
      address = '$host:$port/$path';
    }

    if (useTLS) {
      address = 'https://$address';
    } else {
      address = 'http://$address';
    }
    uri = Uri.parse(address);
    hostAndPort = '${uri.host}:${uri.port}';

    await _connect();

    clientTransportStream = con.makeRequest(header, endStream: false);
    return RRSSocket(socket: H2Socket(transportStream: clientTransportStream));
  }

  Future<void> close() async {
    clientTransportStream.outgoingMessages.close();
    info['link'] -= 1;
    if (info['link'] == 0) {
      info['isClosed'] = true;
      liveConnection.remove(hostAndPort);
      await con.finish();
    }
  }
}
