@IsTest
private class FhirPatientMapper_Test {
  private static Map<String, Object> patient(String json) {
    return (Map<String, Object>) System.JSON.deserializeUntyped(json);
  }

  @IsTest
  static void mapsFullPatient() {
    Contact c = FhirPatientMapper.toContact(
      patient(
        '{"resourceType":"Patient","id":"syn-1","meta":{"lastUpdated":"2026-10-30T08:15:00Z"},' +
          '"name":[{"use":"nickname","given":["AJ"],"family":"Nick"},{"use":"official","family":"Rivera","given":["Alex","J"]}],' +
          '"gender":"female","birthDate":"1984-03-12",' +
          '"telecom":[{"system":"phone","value":"555-010-2001"},{"system":"email","value":"alex@example.com"}],' +
          '"address":[{"line":["100 Demo St","Apt 2"],"city":"Springfield","state":"NY","postalCode":"10001"}]}'
      )
    );
    Assert.areEqual('syn-1', c.FHIR_Id__c);
    Assert.areEqual('Rivera', c.LastName, 'Official name preferred');
    Assert.areEqual('Alex', c.FirstName);
    Assert.areEqual(Date.newInstance(1984, 3, 12), c.Birthdate);
    Assert.areEqual('555-010-2001', c.Phone);
    Assert.areEqual('alex@example.com', c.Email);
    Assert.areEqual('100 Demo St\nApt 2', c.MailingStreet);
    Assert.areEqual('female', c.FHIR_Gender__c);
    Assert.isNotNull(c.FHIR_Last_Updated__c);
  }

  @IsTest
  static void fallsBackToFirstName() {
    Contact c = FhirPatientMapper.toContact(
      patient('{"id":"syn-2","name":[{"family":"Lee"}],"birthDate":"1990"}')
    );
    Assert.areEqual('Lee', c.LastName);
    Assert.isNull(c.FirstName);
    Assert.isNull(c.Birthdate, 'Partial dates are ignored');
  }

  @IsTest
  static void rejectsMissingFamilyName() {
    try {
      FhirPatientMapper.toContact(patient('{"id":"syn-3","name":[{"given":["X"]}]}'));
      Assert.fail('Expected MappingException');
    } catch (FhirPatientMapper.MappingException ex) {
      Assert.isTrue(ex.getMessage().contains('no family name'));
    }
  }

  @IsTest
  static void rejectsMissingId() {
    try {
      FhirPatientMapper.toContact(patient('{"name":[{"family":"X"}]}'));
      Assert.fail('Expected MappingException');
    } catch (FhirPatientMapper.MappingException ex) {
      Assert.isTrue(ex.getMessage().contains('no id'));
    }
  }
}
