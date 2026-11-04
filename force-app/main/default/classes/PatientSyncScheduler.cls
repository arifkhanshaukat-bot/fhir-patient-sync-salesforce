/**
 * Nightly entry point:
 *   System.schedule('FHIR patient sync', '0 0 2 * * ?', new PatientSyncScheduler());
 */
public with sharing class PatientSyncScheduler implements Schedulable {
  public void execute(SchedulableContext sc) {
    System.enqueueJob(new PatientSyncJob());
  }
}
