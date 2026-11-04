{
  "resourceType": "Bundle",
  "type": "searchset",
  "total": 3,
  "link": [
    {
      "relation": "self",
      "url": "https://fhir.example.test/Patient?_count=50"
    },
    {
      "relation": "next",
      "url": "https://fhir.example.test/Patient?_count=50&_page=2"
    }
  ],
  "entry": [
    {
      "resource": {
        "resourceType": "Patient",
        "id": "syn-1001",
        "meta": {
          "lastUpdated": "2026-10-30T08:15:00Z"
        },
        "name": [
          {
            "use": "official",
            "family": "Rivera",
            "given": [
              "Alex",
              "J"
            ]
          }
        ],
        "gender": "female",
        "birthDate": "1984-03-12",
        "telecom": [
          {
            "system": "phone",
            "value": "555-010-2001"
          },
          {
            "system": "email",
            "value": "alex.rivera@example.com"
          }
        ],
        "address": [
          {
            "line": [
              "100 Demo Street"
            ],
            "city": "Springfield",
            "state": "NY",
            "postalCode": "10001"
          }
        ]
      }
    },
    {
      "resource": {
        "resourceType": "Patient",
        "id": "syn-1002",
        "meta": {
          "lastUpdated": "2026-10-30T09:00:00Z"
        },
        "name": [
          {
            "use": "usual",
            "given": [
              "Sam"
            ],
            "family": "Patel"
          }
        ],
        "gender": "male",
        "birthDate": "1990-11-02"
      }
    },
    {
      "resource": {
        "resourceType": "Patient",
        "id": "syn-1003",
        "meta": {
          "lastUpdated": "2026-10-30T09:30:00Z"
        },
        "name": [
          {
            "given": [
              "NoFamilyName"
            ]
          }
        ]
      }
    }
  ]
}
