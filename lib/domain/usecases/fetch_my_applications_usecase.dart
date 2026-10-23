import 'package:scn_jobs/core/network/pagination.dart';
import 'package:scn_jobs/domain/entities/application.dart';
import 'package:scn_jobs/domain/repositories/application_repository.dart';

class FetchMyApplicationsUseCase {
  const FetchMyApplicationsUseCase(this._repository);
  final ApplicationRepository _repository;

  Future<Page<Application>> call({String? cursor}) {
    return _repository.getMyApplications(cursor: cursor);
  }
}
