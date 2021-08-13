library LungCancerConcepts version '0.1.0'

codesystem "SNOMED": 'http://snomed.info/sct'
codesystem "UTAH_EDU": 'http://utah.edu/epic/proc_code'
codesystem "LOINC": 'http://loinc.org'

valueset "Lung Cancer":  'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1116.89'
valueset "Smoking Status": 'http://hl7.org/fhir/us/core/ValueSet/us-core-observation-smokingstatus'
valueset "Current Smoker": 'http://fhir.org/guides/utah-edu/lcs-cds/ValueSet/currentsmoker'
valueset "Chest CT": 'http://fhir.org/guides/utah-edu/lcs-cds/ValueSet/chest-ct-proc-code'
valueset "Condition Clinical Status": 'http://fhir.org/guides/utah-edu/lcs-cds/ValueSet/conditionclinical'

code "Tobacco Smoking Status": '72166-2' from "LOINC"
code "Former Smoker": '8517006' from "SNOMED"
code "Never Smoker": '266919005' from "SNOMED"
code "PACKS A DAY": '8663-7' from "LOINC" display 'packs per day'
