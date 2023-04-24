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

class GunServiceClient extends $grpc.Client {
  static final _$tun = $grpc.ClientMethod<$0.Hunk, $0.Hunk>(
      '/v2ray.core.transport.internet.grpc.encoding.GunService/Tun',
      ($0.Hunk value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.Hunk.fromBuffer(value));

  GunServiceClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options, interceptors: interceptors);

  $grpc.ResponseStream<$0.Hunk> tun($async.Stream<$0.Hunk> request,
      {$grpc.CallOptions? options}) {
    return $createStreamingCall(_$tun, request, options: options);
  }
}

abstract class GunServiceBase extends $grpc.Service {
  $core.String get $name =>
      'v2ray.core.transport.internet.grpc.encoding.GunService';

  GunServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.Hunk, $0.Hunk>(
        'Tun',
        tun,
        true,
        true,
        ($core.List<$core.int> value) => $0.Hunk.fromBuffer(value),
        ($0.Hunk value) => value.writeToBuffer()));
  }

  $async.Stream<$0.Hunk> tun(
      $grpc.ServiceCall call, $async.Stream<$0.Hunk> request);
}
