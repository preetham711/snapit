import 'package:equatable/equatable.dart';
import '../models/memory_model.dart';

abstract class AppEvent extends Equatable {
  const AppEvent();

  @override
  List<Object?> get props => [];
}

class InitializeAppEvent extends AppEvent {
  const InitializeAppEvent();
}

class LoadMemoriesEvent extends AppEvent {
  const LoadMemoriesEvent();
}

class LoadPeopleEvent extends AppEvent {
  const LoadPeopleEvent();
}

class SaveMemoryEvent extends AppEvent {
  final Memory memory;

  const SaveMemoryEvent(this.memory);

  @override
  List<Object?> get props => [memory];
}

class SavePersonEvent extends AppEvent {
  final Person person;

  const SavePersonEvent(this.person);

  @override
  List<Object?> get props => [person];
}

class DeleteMemoryEvent extends AppEvent {
  final String memoryId;

  const DeleteMemoryEvent(this.memoryId);

  @override
  List<Object?> get props => [memoryId];
}

class DeletePersonEvent extends AppEvent {
  final String personId;

  const DeletePersonEvent(this.personId);

  @override
  List<Object?> get props => [personId];
}

class SearchMemoriesEvent extends AppEvent {
  final String query;

  const SearchMemoriesEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class UpdateSettingEvent extends AppEvent {
  final String key;
  final dynamic value;

  const UpdateSettingEvent(this.key, this.value);

  @override
  List<Object?> get props => [key, value];
}
