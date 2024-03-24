import 'package:protoo_client/protoo_client.dart';

const url = 'wss://v3demo.mediasoup.org:4443';
const roomId = 'asdasdds';
const peerId = 'zxcvvczx';

void main() async {
  final peer = Peer(Transport('$url/?roomId=$roomId&peerId=$peerId'));

  peer
    ..on('open', () {
      print('open');

      peer.request('method', 'getRouterRtpCapabilities').then((data) {
        print('response: ' + data.toString());
      }).catchError((error) {
        print('response error: ' + error.toString());
      });
    })
    ..on('close', () {
      print('close');
    })
    ..on('error', (error) {
      print('error ' + error);
    })
    ..on('request', (request, accept, reject) {
      print('request: $request');
      accept({'key1': "value1", 'key2': "value2"});
      //reject(404, 'Oh no~~~~~');
    });

  //await peer.connect();

  //peer.close();
}
