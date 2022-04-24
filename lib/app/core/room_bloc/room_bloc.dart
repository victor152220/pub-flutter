import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/cupertino.dart';
import 'package:meta/meta.dart';
import 'package:socket_io_client/socket_io_client.dart';

import '../../pages/room/models/bloc_events.dart';
import '../../pages/room/models/data/data.dart';
import '../../pages/room/models/data/enter_public_room_data.dart';

import '../../pages/room/models/data/leave_public_room_data.dart';
import '../../pages/room/models/data/message_data.dart';
import '../../pages/room/models/data/rooms_list_data.dart';
import '../../pages/room/models/room.dart';
import '../../pages/room/view_models/room_view_model.dart';
import '../../pages/user/models/user.dart';
import '../configs/app_routes.dart';

part 'room_event.dart';
part 'room_state.dart';

class RoomBloc extends Bloc<RoomEvent,RoomState>{
  late final Socket _socket;
  final Room room;
  final User user;
  final RoomViewModel roomViewModel;
  RoomBloc({required this.room,required this.user,required this.roomViewModel}) : super(InitialState(roomViewModel: roomViewModel)) {
    _socket = io(urlServer, OptionBuilder().setTransports(['websocket']).build());
    _socket.connect();

    _socket.on('public_message_data', (data) => add(ReceiveMessageEvent(data)));
    _socket.on('broad_enter_public_room', (data) => add(ReceiveMessageEvent(data)));
    _socket.on('user_enter_public_room', (data) => add(ReceiveMessageEvent(data)));
    _socket.on('leave_public_room', (data) => add(ReceiveMessageEvent(data)));
    _socket.on('initial_rooms_list', (data) => add(ReceiveMessageEvent(data)));

    on<InitialEvent>((event, emit) async{
      _socket.emit('enter_public_room', {
        'roomName': this.room.getRoomName,
        'user': this.user.toMap()
      });
    });

    on<LoadingRoomsListEvent>((event, emit) async{
      _socket.emit('initial_rooms_list', {
        'latitude': event.latitude,
        'longitude': event.longitude
      });
      _socket.onConnect((_) {
      });
    });
    on<SendMessageEvent>((event, emit) async{
      _socket.emit('public_message',event.message);
      emit(SendMessageState(roomViewModel: roomViewModel));
    });

    on<DisconnectEvent>((event, emit) async{
      _socket.emit('leave_public_room', {
        'roomName': this.room.getRoomName,
        'userNickName': this.user.getNickname
      });
      _socket.onDisconnect((_) {
      });
    });

    on<ReceiveMessageEvent>((event, emit) async{

      Data data = Data.fromMap(event.message);

      switch(data.type){
        case BlocEventType.update_rooms_list:
          return emit(SuccessRoomsListState(message:RoomsListData.fromMap(event.message),roomViewModel: roomViewModel));
        case BlocEventType.broad_enter_public_room:
          return emit(ReceiveBroadEnterPublicRoomMessageState(message:EnterPublicRoomData.fromMap(event.message),roomViewModel: roomViewModel));
        case BlocEventType.user_enter_public_room:
          return emit(ReceiveUserEnterPublicRoomMessageState(message:EnterPublicRoomData.fromMap(event.message),roomViewModel: roomViewModel));
        case BlocEventType.leave_public_room:
          return emit(ReceiveLeavePublicRoomMessageState(message:LeavePublicRoomData.fromMap(event.message),roomViewModel: roomViewModel));
        case BlocEventType.typing:
          return emit(ReceiveTypingMessageState(roomViewModel: roomViewModel));
        case BlocEventType.stopped_typing:
          return emit(ReceiveStoppedTypingMessageState(roomViewModel: roomViewModel));
        case BlocEventType.receive_public_message:
          return emit(ReceiveMessageState(message:MessageData.fromMap(event.message),roomViewModel: roomViewModel));
        case BlocEventType.delete_message:
          return emit(ReceiveDeleteMessageState(roomViewModel: roomViewModel));
        case BlocEventType.edit_message:
          return emit(ReceiveEditMessageState(roomViewModel: roomViewModel));
        default:
          break;
      }
    }
    );
    on<DontBuildEvent>((event, emit) async{
      emit(DontBuildState(roomViewModel: roomViewModel));
    });
  }
  @override
  Future<void> close() {
    _socket.clearListeners();
    _socket.close();
    return super.close();
  }
}


