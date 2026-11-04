/**
 * Maps a FHIR R4 Patient resource to a Contact. Pure function with no SOQL/DML so it is
 * easy to unit test. Records without a family name are rejected with a readable reason.
 */
public inherited sharing class FhirPatientMapper {
  public class MappingException extends Exception {
  }

  public static Contact toContact(Map<String, Object> patient) {
    String fhirId = (String) patient.get('id');
    if (String.isBlank(fhirId)) {
      throw new MappingException('Patient resource has no id.');
    }
    Map<String, Object> name = pickName(asList(patient.get('name')));
    String family = name == null ? null : (String) name.get('family');
    if (String.isBlank(family)) {
      throw new MappingException(
        'Patient ' + fhirId + ' has no family name; Contact.LastName is required.'
      );
    }
    List<Object> given = name == null ? new List<Object>() : asList(name.get('given'));

    Contact c = new Contact(
      FHIR_Id__c = fhirId,
      LastName = family.left(80),
      FirstName = given.isEmpty() ? null : String.valueOf(given[0]).left(40),
      FHIR_Gender__c = (String) patient.get('gender')
    );
    String birth = (String) patient.get('birthDate');
    if (String.isNotBlank(birth) && birth.length() == 10) {
      c.Birthdate = Date.valueOf(birth);
    }
    for (Object t : asList(patient.get('telecom'))) {
      Map<String, Object> tel = (Map<String, Object>) t;
      if ('phone'.equals(tel.get('system')) && c.Phone == null) {
        c.Phone = (String) tel.get('value');
      } else if ('email'.equals(tel.get('system')) && c.Email == null) {
        c.Email = (String) tel.get('value');
      }
    }
    List<Object> addresses = asList(patient.get('address'));
    if (!addresses.isEmpty()) {
      Map<String, Object> addr = (Map<String, Object>) addresses[0];
      List<Object> lines = asList(addr.get('line'));
      List<String> lineStrings = new List<String>();
      for (Object l : lines) {
        lineStrings.add(String.valueOf(l));
      }
      c.MailingStreet = String.join(lineStrings, '\n');
      c.MailingCity = (String) addr.get('city');
      c.MailingState = (String) addr.get('state');
      c.MailingPostalCode = (String) addr.get('postalCode');
    }
    Map<String, Object> meta = (Map<String, Object>) patient.get('meta');
    if (meta != null && meta.get('lastUpdated') != null) {
      c.FHIR_Last_Updated__c = (Datetime) JSON.deserialize(
        '"' + meta.get('lastUpdated') + '"',
        Datetime.class
      );
    }
    return c;
  }

  /** Prefer the "official" name, then "usual", then the first one. */
  @TestVisible
  private static Map<String, Object> pickName(List<Object> names) {
    Map<String, Object> fallback;
    for (String preferred : new List<String>{ 'official', 'usual' }) {
      for (Object n : names) {
        Map<String, Object> m = (Map<String, Object>) n;
        if (preferred.equals(m.get('use'))) {
          return m;
        }
      }
    }
    if (!names.isEmpty()) {
      fallback = (Map<String, Object>) names[0];
    }
    return fallback;
  }

  private static List<Object> asList(Object o) {
    return o == null ? new List<Object>() : (List<Object>) o;
  }
}
