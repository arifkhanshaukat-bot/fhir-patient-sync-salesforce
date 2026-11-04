@IsTest
private class PatientSyncJob_Test {
  @IsTest
  static void upsertsValidPatientsAndLogsInvalidOnes() {
    Test.setMock(HttpCalloutMock.class, new FhirMock().add(200, FhirMock.sampleBundle()));
    Test.startTest();
    System.enqueueJob(new PatientSyncJob());
    Test.stopTest();

    Assert.areEqual(2, [SELECT COUNT() FROM Contact WHERE FHIR_Id__c LIKE 'syn-%']);
    List<Integration_Error__c> errors = [
      SELECT External_Id__c, Message__c
      FROM Integration_Error__c
    ];
    Assert.areEqual(1, errors.size());
    Assert.areEqual('syn-1003', errors[0].External_Id__c);
    Assert.isTrue(errors[0].Message__c.contains('no family name'));
  }

  @IsTest
  static void isIdempotent() {
    Map<String, Object> p = (Map<String, Object>) JSON.deserializeUntyped(
      '{"id":"syn-9","name":[{"family":"Okafor"}]}'
    );
    PatientSyncJob.upsertPatients(new List<Map<String, Object>>{ p });
    PatientSyncJob.SyncResult second = PatientSyncJob.upsertPatients(
      new List<Map<String, Object>>{ p }
    );
    Assert.areEqual(1, second.upserted);
    Assert.areEqual(1, [SELECT COUNT() FROM Contact WHERE FHIR_Id__c = 'syn-9']);
  }

  @IsTest
  static void logsCalloutFailure() {
    Test.setMock(HttpCalloutMock.class, new FhirMock().add(401, '{"issue":"unauthorized"}'));
    Test.startTest();
    System.enqueueJob(new PatientSyncJob());
    Test.stopTest();
    Integration_Error__c err = [
      SELECT Status_Code__c, Message__c
      FROM Integration_Error__c
      LIMIT 1
    ];
    Assert.areEqual(401, err.Status_Code__c);
  }

  @IsTest
  static void schedulerEnqueuesJob() {
    Test.setMock(HttpCalloutMock.class, new FhirMock().add(200, '{"resourceType":"Bundle"}'));
    Test.startTest();
    new PatientSyncScheduler().execute(null);
    Test.stopTest();
    Assert.areEqual(0, [SELECT COUNT() FROM Integration_Error__c]);
  }

  @IsTest
  static void settingsHaveDefaults() {
    Assert.isNotNull(PatientSyncJob.settings().Page_Size__c);
  }
}
