/** Configurable HttpCalloutMock: returns queued responses in order. */
@IsTest
public class FhirMock implements HttpCalloutMock {
  private final List<HttpResponse> queue = new List<HttpResponse>();
  public List<HttpRequest> requests = new List<HttpRequest>();

  public FhirMock add(Integer status, String body) {
    HttpResponse r = new HttpResponse();
    r.setStatusCode(status);
    r.setBody(body == null ? '' : body);
    r.setHeader('Content-Type', 'application/fhir+json');
    queue.add(r);
    return this;
  }

  public HttpResponse respond(HttpRequest req) {
    requests.add(req);
    if (queue.isEmpty()) {
      throw new CalloutException('No more mock responses queued');
    }
    return queue.remove(0);
  }

  public static String sampleBundle() {
    return [SELECT Body FROM StaticResource WHERE Name = 'FhirSampleBundle' LIMIT 1]
      .Body.toString();
  }
}
