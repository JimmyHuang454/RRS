///
//  Generated code. Do not modify.
//  source: grpc.proto
//
// @dart = 2.12
// ignore_for_file: annotate_overrides,camel_case_types,constant_identifier_names,directives_ordering,library_prefixes,non_constant_identifier_names,prefer_final_fields,return_of_invalid_type,unnecessary_const,unnecessary_import,unnecessary_this,unused_import,unused_shown_name

import 'dart:async' as $async;

import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'grpc.pb.dart' as $0;
export 'grpc.pb.dart';

class RRSClient extends $grpc.Client {
  static final _$connect = $grpc.ClientMethod<$0.StreamMsg, $0.StreamMsg>(
      '/RRSTransport.RRS/Connect',
      ($0.StreamMsg value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.StreamMsg.fromBuffer(value));

  RRSClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options, interceptors: interceptors);

  $grpc.ResponseStream<$0.StreamMsg> connect(
      $async.Stream<$0.StreamMsg> request,
      {$grpc.CallOptions? options}) {
    return $createStreamingCall(_$connect, request, options: options);
  }
}

abstract class RRSServiceBase extends $grpc.Service {
  $core.String get $name => 'RRSTransport.RRS';

  RRSServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.StreamMsg, $0.StreamMsg>(
        'Connect',
        connect,
        true,
        true,
        ($core.List<$core.int> value) => $0.StreamMsg.fromBuffer(value),
        ($0.StreamMsg value) => value.writeToBuffer()));
  }

  $async.Stream<$0.StreamMsg> connect(
      $grpc.ServiceCall call, $async.Stream<$0.StreamMsg> request);
}
