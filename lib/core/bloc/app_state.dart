import 'package:equatable/equatable.dart';
import '../models/memory_model.dart';

abstract class AppState extends Equatable {
  const AppState();

  @override
  List<Object?> get props => [];
}

class AppInitial extends AppState {
  const AppInitial();
}

class AppLoading extends AppState {
  const AppLoading();
}

class AppLoaded extends AppState {
  final List<Memory> memories;
  final List<Person> people;
  final Map<String, dynamic> settings;

  const AppLoaded({
    required this.memories,
    required this.people,
    required this.settings,
  });

  @override
  List<Object?> get props => [memories, people, settings];
}

class AppError extends AppState {
  final String message;

  const AppError(this.message);

  @override
  List<Object?> get props => [message];
}

class SearchResults extends AppState {
  final List<Memory> memories;
  final List<Person> people;

  const SearchResults({
    required this.memories,
    required this.people,
  });

  @override
  List<Object?> get props => [memories, people];
}
