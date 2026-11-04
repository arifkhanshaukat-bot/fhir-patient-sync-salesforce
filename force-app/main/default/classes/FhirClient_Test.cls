@IsTest
private class FhirClient_Test {
  @IsTest
  static void parsesBundleAndNextLink() {
    FhirMock mock = new FhirMock().add(200, FhirMock.sampleBundle());
    Test.setMock(HttpCalloutMock.class, mock);
    Test.startTest();
    FhirClient.Page page = new FhirClient(0)
      .fetchUpdatedPatients(Datetime.newInstanceGmt(2026, 10, 30), 50);
    Test.stopTest();
    Assert.areEqual(3, page.patients.size());
    Assert.isTrue(page.nextUrl.contains('_page=2'));
    Assert.isTrue(
      mock.requests[0].getEndpoint().startsWith('callout:FHIR_Server/Patient?_count=50')
    );
    Assert.isTrue(mock.requests[0].getEndpoint().contains('_lastUpdated=ge2026-10-30'));
  }

  @IsTest
  static void retriesTransientErrors() {
    FhirMock mock = new FhirMock()
      .add(503, 'busy')
      .add(429, 'slow down')
      .add(200, '{"resourceType":"Bundle","entry":[]}');
    Test.setMock(HttpCalloutMock.class, mock);
    Test.startTest();
    FhirClient.Page page = new FhirClient(2).fetchUpdatedPatients(null, 10);
    Test.stopTest();
    Assert.areEqual(3, mock.requests.size());
    Assert.areEqual(0, page.patients.size());
    Assert.isNull(page.nextUrl);
  }

  @IsTest
  static void givesUpAfterMaxRetries() {
    Test.setMock(HttpCalloutMock.class, new FhirMock().add(500, 'err').add(500, 'err'));
    try {
      new FhirClient(1).fetchUpdatedPatients(null, 10);
      Assert.fail('Expected FhirCalloutException');
    } catch (FhirClient.FhirCalloutException ex) {
      Assert.areEqual(500, ex.statusCode);
      Assert.isTrue(ex.getMessage().contains('after 2 attempts'));
    }
  }

  @IsTest
  static void doesNotRetryClientErrors() {
    FhirMock mock = new FhirMock().add(404, 'nope');
    Test.setMock(HttpCalloutMock.class, mock);
    try {
      new FhirClient(3).fetchUpdatedPatients(null, 10);
      Assert.fail('Expected FhirCalloutException');
    } catch (FhirClient.FhirCalloutException ex) {
      Assert.areEqual(404, ex.statusCode);
      Assert.areEqual(1, mock.requests.size());
    }
  }

  @IsTest
  static void nextLinkIsRebasedOnNamedCredential() {
    FhirMock mock = new FhirMock().add(200, '{"resourceType":"Bundle"}');
    Test.setMock(HttpCalloutMock.class, mock);
    new FhirClient(0).fetchNext('https://attacker.example/baseR4/Patient?_page=2');
    Assert.areEqual('callout:FHIR_Server/Patient?_page=2', mock.requests[0].getEndpoint());
  }

  @IsTest
  static void refusesUnexpectedNextLink() {
    try {
      new FhirClient(0).fetchNext('https://fhir.example.test/Observation?_page=2');
      Assert.fail('Expected FhirCalloutException');
    } catch (FhirClient.FhirCalloutException ex) {
      Assert.isTrue(ex.getMessage().contains('refusing'));
    }
  }
}
