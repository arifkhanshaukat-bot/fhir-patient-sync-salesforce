/**
 * Pulls changed FHIR Patients one page at a time and upserts them to Contact by FHIR_Id__c.
 *
 * Why Queueable chaining instead of Database.Batchable: the source is a paged REST API, not a
 * SOQL query. Each job handles one page (one callout transaction) and enqueues the next page,
 * up to Max_Pages__c per run. Failures are written to Integration_Error__c with a readable
 * message so support can triage without reading debug logs.
 */
public with sharing class PatientSyncJob implements Queueable, Database.AllowsCallouts {
  public static final String SOURCE = 'FHIR Patient Sync';

  private final String nextUrl;
  private final Integer pageNumber;

  public PatientSyncJob() {
    this(null, 1);
  }

  @TestVisible
  private PatientSyncJob(String nextUrl, Integer pageNumber) {
    this.nextUrl = nextUrl;
    this.pageNumber = pageNumber;
  }

  public void execute(QueueableContext ctx) {
    FHIR_Sync_Setting__mdt cfg = settings();
    FhirClient client = new FhirClient(cfg.Max_Retries__c.intValue());
    FhirClient.Page page;
    try {
      page = nextUrl == null
        ? client.fetchUpdatedPatients(
            Datetime.now().addHours(-cfg.Lookback_Hours__c.intValue()),
            cfg.Page_Size__c.intValue()
          )
        : client.fetchNext(nextUrl);
    } catch (FhirClient.FhirCalloutException ex) {
      insert as user new Integration_Error__c(
        Source__c = SOURCE,
        Message__c = ex.getMessage(),
        Status_Code__c = ex.statusCode,
        Payload__c = ex.responseBody == null ? null : ex.responseBody.left(131072)
      );
      return;
    }

    SyncResult result = upsertPatients(page.patients);
    if (!result.errors.isEmpty()) {
      insert as user result.errors;
    }

    if (page.nextUrl != null && pageNumber < cfg.Max_Pages__c.intValue() && !Test.isRunningTest()) {
      System.enqueueJob(new PatientSyncJob(page.nextUrl, pageNumber + 1));
    }
  }

  public class SyncResult {
    public Integer upserted = 0;
    public List<Integration_Error__c> errors = new List<Integration_Error__c>();
  }

  @TestVisible
  private static SyncResult upsertPatients(List<Map<String, Object>> patients) {
    SyncResult result = new SyncResult();
    List<Contact> contacts = new List<Contact>();
    for (Map<String, Object> p : patients) {
      try {
        contacts.add(FhirPatientMapper.toContact(p));
      } catch (FhirPatientMapper.MappingException ex) {
        result.errors.add(errorFor((String) p.get('id'), ex.getMessage(), JSON.serialize(p)));
      }
    }
    Database.UpsertResult[] results = Database.upsert(
      contacts,
      Contact.FHIR_Id__c,
      false,
      AccessLevel.USER_MODE
    );
    for (Integer i = 0; i < results.size(); i++) {
      if (results[i].isSuccess()) {
        result.upserted++;
      } else {
        result.errors.add(
          errorFor(contacts[i].FHIR_Id__c, results[i].getErrors()[0].getMessage(), null)
        );
      }
    }
    return result;
  }

  private static Integration_Error__c errorFor(String externalId, String message, String payload) {
    return new Integration_Error__c(
      Source__c = SOURCE,
      External_Id__c = externalId,
      Message__c = message == null ? null : message.left(255),
      Payload__c = payload == null ? null : payload.left(131072)
    );
  }

  @TestVisible
  private static FHIR_Sync_Setting__mdt settings() {
    FHIR_Sync_Setting__mdt cfg = FHIR_Sync_Setting__mdt.getInstance('Default');
    if (cfg == null) {
      cfg = new FHIR_Sync_Setting__mdt(
        Page_Size__c = 50,
        Max_Retries__c = 2,
        Max_Pages__c = 20,
        Lookback_Hours__c = 24
      );
    }
    return cfg;
  }
}
