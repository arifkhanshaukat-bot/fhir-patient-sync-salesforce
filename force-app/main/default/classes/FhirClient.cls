/**
 * Minimal FHIR R4 client for the Patient endpoint. All callouts go through the
 * FHIR_Server Named Credential, so no endpoint or secret lives in code.
 * Retries transient failures (429 and 5xx) up to the configured limit.
 */
public with sharing class FhirClient {
  public class FhirCalloutException extends Exception {
    public Integer statusCode;
    public String responseBody;
  }

  public class Page {
    public List<Map<String, Object>> patients = new List<Map<String, Object>>();
    public String nextUrl;
  }

  @TestVisible
  private static final String NAMED_CREDENTIAL = 'callout:FHIR_Server';
  private final Integer maxRetries;

  public FhirClient(Integer maxRetries) {
    this.maxRetries = maxRetries == null ? 0 : maxRetries;
  }

  /** First page of patients updated since the given time. */
  public Page fetchUpdatedPatients(Datetime since, Integer pageSize) {
    String path = '/Patient?_count=' + pageSize + '&_sort=_lastUpdated';
    if (since != null) {
      path +=
        '&_lastUpdated=ge' +
        EncodingUtil.urlEncode(since.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''), 'UTF-8');
    }
    return parse(send(NAMED_CREDENTIAL + path));
  }

  /**
   * Follows a server-provided "next" link. Only the path and query are kept and re-based on
   * the Named Credential, so a tampered link cannot redirect the callout to another host.
   */
  public Page fetchNext(String nextUrl) {
    Url u = new Url(nextUrl);
    String pathAndQuery = u.getPath() + (u.getQuery() == null ? '' : '?' + u.getQuery());
    Integer idx = pathAndQuery.indexOf('/Patient');
    if (idx < 0) {
      throw new FhirCalloutException('Unexpected next link; refusing to follow.');
    }
    return parse(send(NAMED_CREDENTIAL + pathAndQuery.substring(idx)));
  }

  @TestVisible
  private HttpResponse send(String endpoint) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint(endpoint);
    req.setMethod('GET');
    req.setHeader('Accept', 'application/fhir+json');
    req.setTimeout(30000);

    HttpResponse res;
    for (Integer attempt = 0; attempt <= maxRetries; attempt++) {
      res = new Http().send(req);
      Integer code = res.getStatusCode();
      if (code >= 200 && code < 300) {
        return res;
      }
      Boolean transientError = code == 429 || code >= 500;
      if (!transientError || attempt == maxRetries) {
        FhirCalloutException ex = new FhirCalloutException(
          'FHIR server returned HTTP ' +
            code +
            (transientError ? ' after ' + (attempt + 1) + ' attempts.' : '.')
        );
        ex.statusCode = code;
        ex.responseBody = res.getBody();
        throw ex;
      }
    }
    return res;
  }

  @TestVisible
  private static Page parse(HttpResponse res) {
    Page page = new Page();
    Map<String, Object> bundle = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    for (Object linkObj : asList(bundle.get('link'))) {
      Map<String, Object> link = (Map<String, Object>) linkObj;
      if ('next'.equals(link.get('relation'))) {
        page.nextUrl = (String) link.get('url');
      }
    }
    for (Object entryObj : asList(bundle.get('entry'))) {
      Map<String, Object> resource = (Map<String, Object>) ((Map<String, Object>) entryObj)
        .get('resource');
      if (resource != null && 'Patient'.equals(resource.get('resourceType'))) {
        page.patients.add(resource);
      }
    }
    return page;
  }

  private static List<Object> asList(Object o) {
    return o == null ? new List<Object>() : (List<Object>) o;
  }
}
