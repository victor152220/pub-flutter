import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:pub/app/core/configs/app_colors.dart';
import 'package:pub/app/pages/participant/models/participant.dart';
import 'package:pub/app/pages/user/models/user.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/room_bloc/room_bloc.dart';
import '../models/bloc_events.dart';

import '../models/data/public_room_data.dart';
import '../models/data/message_data.dart';
import '../models/room.dart';

abstract class IRoomViewModel{
  getPosition();
  sendMessage(RoomBloc bloc);
}

class RoomViewModel extends ChangeNotifier implements IRoomViewModel{


  RoomViewModel({required this.scrollViewController, required User user,required Room room}): _user = user, _room = room{
    getPosition();
  }
  final ScrollController scrollViewController;
  final Uri _url = Uri.parse('https://flutter.dev');
  final focusNode = FocusNode();
  final textController = TextEditingController(text: '');
  // late bool boolAdd;
  String error = '';
  List<dynamic> _rooms = [];
  Room _room;
  User _user;
  bool isParticipantExist = false;
  int lineNumbers = 1;

  // bool isVisibled = false;
  verifyLocation(BuildContext context,RoomBloc bloc){
    Geolocator.getPositionStream(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(minutes: 2))
    ).listen((position) {
      double distance = (Geolocator.distanceBetween(position.latitude, position.longitude, getRoom.getLatitude, getRoom.getLongitude) / 1000);
      if(distance > 0.0){
        bloc.add(DisconnectEvent(context));
      }
    });
  }

  sendMessage(RoomBloc bloc){

    String textMessage = textController.text;

    if (textMessage.isNotEmpty) {

      var mes = MessageData(
          idRoom: this.getRoom.getIdRoom,
          createdAt: DateTime.now().toString(),
          roomName: this.getRoom.getRoomName,
          idMessage: '',
          textMessage: textMessage,
          user: this.getUser,
          code: 0,
          type: BlocEventType.send_public_message);

      _room.getMessages.add(mes);

      bloc.add(SendMessageEvent(mes.toMap()));
      focusNode.requestFocus();
      textController.clear();
      focusNode.requestFocus();
    }
  }

  checkAccessToLocation() async{
    LocationPermission permission = await Geolocator.checkPermission();
    if(permission == LocationPermission.denied){
      permission = await Geolocator.requestPermission();
      if(permission != LocationPermission.denied){
        return;
      }
    }
    if(permission == LocationPermission.deniedForever){
      permission = await Geolocator.requestPermission();
      if(permission != LocationPermission.deniedForever){
        return;
      }
    }
  }
  void getPosition() async{
    // try{
    //   bool active = await Geolocator.isLocationServiceEnabled();
    //   if(!active){
    //    checkAccessToLocation();
    //   }
    // Position position = await Geolocator.getCurrentPosition( desiredAccuracy: LocationAccuracy.best);
    // developer.log('log latitude: ${position.latitude.toString()}');
    // getUser.setLatitude(position.latitude);
    // developer.log('log longitude: ${position.longitude.toString()}');
    // getUser.setLongitude(position.longitude);
    getUser.setLatitude(-10.182642569502747);
    getUser.setLongitude(-48.36052358794835);
    // }catch(e){
    //   error = e.toString();
    // }
  }
  // Future<Position> _currentPosition() async{
  //   bool active = await Geolocator.isLocationServiceEnabled();
  //   if(!active){
  //     return Future.error('Por favor, habilite a localizacao');
  //   }
  //   return await Geolocator.getCurrentPosition();
  // }
  void dispose() {
    super.dispose();
    textController.dispose();
    focusNode.dispose();
    scrollViewController.dispose();
  }

  Alignment alignment(state,index){
    if(state is SendMessageState || state is ReceivePublicMessageState) {
      if(_room.getMessages[index].getUser.getNickname != _user.getNickname){
        return  Alignment.centerLeft;
      } else{
        return Alignment.centerRight;
      }
    } else{
      return Alignment.center;
    }
  }
  Color color(state,index){
    if(state is SendMessageState || state is ReceivePublicMessageState) {
      if(_room.getMessages[index].getUser.getNickname != _user.getNickname){
        return  Colors.white;
      } else{
        return Color(0xffdcd9d9);
      }
    } else {
      return AppColors.lightBrown;
    }
  }

  typeMessage(state, index) {
    // Timer(Duration(microseconds: 50), (){
    //   this.scrollViewController.jumpTo(
    //       this.scrollViewController.position.maxScrollExtent
    //   );
    // });
    if(state is SendMessageState || state is ReceivePublicMessageState) {
      return Text('${_room.getMessages[index].getUser.getNickname} - ${_room.getMessages[index].getTextMessage}');
    } else if(state is EnterPublicRoomMessageState){
      return  Center(child: Text('${state.message.getUser.getNickName} entrou na sala'));
    }
  }
  verifyParticipants(room, data) {
    for (dynamic participant in room.getParticipants) {
      if (data.getUser.getNickname == participant.getNickname) {
        isParticipantExist = true;
      }
    }
  }
  void addParticipants(PublicRoomData data) {
    if(data.getUser.getNickname == getUser.getNickname){
      getUser.setIdUser(data.getUser.getIdUser);
      getRoom.setIdRoom(data.getIdRoom);
    }else{
      for(dynamic room in _rooms){
        if(room.getIdRoom == data.getIdRoom){
          verifyParticipants(room,data);
          if(!isParticipantExist){
            room.addParticipants(Participant.convertUserToParticipant(data.getUser));
          }
        }
        isParticipantExist = false;
      }
    }
    notifyListeners();
  }
  void removeParticipants(PublicRoomData data) {
    for(dynamic room in _rooms){
      if(room.getIdRoom == data.getIdRoom){
        room.removeParticipants(Participant.convertUserToParticipant(data.getUser));
      }
    }
    notifyListeners();
  }
  double distanceBetweenUserAndEstablishments(User user, double latitude,double longitude) {
    return (Geolocator.distanceBetween(user.getLatitude, user.getLongitude, latitude, longitude) / 1000);
  }

  addMessages(message) {
    // if(boolAdd == true){
    // boolAdd = false;
    getRoom.addMessages(message);
  }
  fetchedRooms(message){
    _rooms = [];
    for(dynamic roomData in message.getRooms){
      Room room = Room.fromMinimalMap(roomData);
      room.setDistance(distanceBetweenUserAndEstablishments(getUser,room.getLatitude,room.getLongitude));
      _rooms.add(room);
    }
  }

  get getUser => _user;
  get getRoom => _room;
  get getRooms => _rooms;

  setRoom(Room room) => _room = room;
  setUser(User user) => _user = user;

  bool isAcceptedLocation(room) {
    double result = distanceBetweenUserAndEstablishments(getUser,room.getLatitude,room.getLongitude);
    if(result <= 0.5)
      return true;
    else
      return false;
  }

  openURL(BuildContext context) async{
    if (await canLaunchUrl(_url))
      await launchUrl(_url);
    else
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possivel abrir a página')));
    /// Não è possível abrir a URL
  }
// reload(RoomBloc bloc) {
//   widget.bloc.add(LoadingRoomsEvent());
// }
}


