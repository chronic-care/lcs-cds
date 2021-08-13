library LungCancerElements version '0.1.0'

using FHIR version '4.0.1'

include FHIRHelpers version '4.0.1'
include FHIRCommon version '4.0.1' called FC

include LungCancerConcepts called Cx

// QUESTION: Should this be a single timepoint, or is a period required?
//parameter AsOf DateTime default Now()

/*
NOTE: Introduced Measurement Period as the parameter here for demonstration purposes
so it will run on the current implementations.
*/
parameter "Measurement Period" Interval<DateTime>
  default Interval[Now() - 1 year, Now()]

context Patient

define AsOf:
  end of "Measurement Period"

define "Chest CT Performed":
  [Procedure: Cx."Chest CT"] ChestCT
    where ChestCT.status = 'completed'

// NOTE: HEDIS version allows for a "history of" SNOMED code as FHIR.Condition. Code is present in eCQM valueset.
define "Chest CT from Patient History":
  [Condition: Cx."Chest CT"] ChestCTCondition
    where ChestCTCondition.clinicalStatus in FC."Active Condition"
      and ChestCTCondition.verificationStatus ~ FC."confirmed"

define "Most Recent Chest CT Performed":
  FC.MostRecent("Chest CT Performed", AsOf)

define "Has History of Chest CT":
 exists (
    "Chest CT from Patient History" ChestCTHistory
      where FC.ToPrevalenceInterval(ChestCTHistory) starts on or before AsOf
  )

define "Has Chest CT Performed Within 1 Year":
  exists (
    FC.PerformedWithin("Chest CT Performed", 1 year, AsOf)
  )

define "Lung Cancer Diagnosis":
  [Condition: Cx."Lung Cancer"] LungCancer
    where LungCancer.clinicalStatus in FC."Active Condition"
      and LungCancer.verificationStatus ~ FC."confirmed"

define "Has Lung Cancer Diagnosis":
  exists (
    "Lung Cancer Diagnosis" C
      where FC.ToPrevalenceInterval(C) starts on or before AsOf
  )

define "Has Appropriate Lung Cancer Screening":
  "Has Chest CT Performed Within 1 Year"

// NOTE: For Condition options
define "Has History of Appropriate Lung Cancer Screening":
  exists (
    "Chest CT from Patient History" ChestCTCondition
      where FC.ToPrevalenceInterval(ChestCTCondition) starts on or after day of AsOf - 1 years)

// When a tobacco smoking status is more than 10 years old, should that be a "warning" surfaced to the clinician in some way?
define "Smoking Status":
  [Observation: Cx."Tobacco Smoking Status"] SmokingStatus
		where SmokingStatus.status in {'final', 'amended', 'corrected', 'preliminary'}
			and SmokingStatus.value is not null

define "Most Recent Smoking Status":
  Last("Smoking Status" O
    sort by (FHIRHelpers.ToDateTime(issued))
  )

define "Smoking Period":
  "Most Recent Smoking Status" O
    let EffectivePeriod: O.effective as FHIR.Period,
    // ToDate() is needed for JavaScript execution due to bug with DateTime duration
    StartDate: ToDate(EffectivePeriod.start.value),
    EndDate: ToDate(Coalesce(EffectivePeriod.end.value, Today()))
    return if StartDate is not null then Interval[StartDate, EndDate] else null

define "Smoking History In Years":
  Round(duration in days of "Smoking Period" / 365.25)

define "Pack-years":
  "Most Recent Smoking Status" O
    let PacksPerDay: singleton from (O.component C where C.code ~ Cx."PACKS A DAY").value.value,
    EffectivePeriod: O.effective as FHIR.Period,
    StartDate: ToDate(EffectivePeriod.start.value),
    EndDate: ToDate(Coalesce(EffectivePeriod.end.value, Today())),
    // DateInterval is needed for JavaScript execution due to bug with DateTime duration
    DurationInDays: duration in days of Interval[StartDate, EndDate]
    return (if (PacksPerDay is not null and StartDate is not null and DurationInDays is not null)
      then System.Quantity { value: Round(PacksPerDay * (DurationInDays / 365.25)), unit: '{Pack-years}' }
    else
      null)

define "Is Current Smoker":
  ("Most Recent Smoking Status" O
    where (O.value as CodeableConcept) in Cx."Current Smoker"
  ) is not null

define "Is Former Smoker":
  ("Most Recent Smoking Status" O
    where (O.value as CodeableConcept) ~ Cx."Former Smoker"
  ) is not null

define "Is Never Smoker":
  ("Most Recent Smoking Status" O
    where (O.value as CodeableConcept) ~ Cx."Never Smoker"
  ) is not null

define "Is former smoker who quit within past 15 years":
  "Is Former Smoker" and ("Most Recent Smoking Status" O
    where O.effective ends 15 years or less before Today()
  ) is not null

define "Is former smoker who quit more than 15 years ago":
  "Is Former Smoker" and ("Most Recent Smoking Status" O
    where O.effective ends more than 15 years before Today()
  ) is not null

define "Has 20 pack-year smoking history":
  "Pack-years" >= 20 '{Pack-years}'

define "Has less than 20 pack-year smoking history":
  "Pack-years" < 20 '{Pack-years}'

define "Packs Per Day":
  "Most Recent Smoking Status" O
    return singleton from (O.component C where C.code ~ Cx."PACKS A DAY").value.value as FHIR.decimal

// Age range for USPSTF guideline as of May 2021
define "Age 50 through 80":
  // Issue: does not include person who turned 50 during the measurement period
  // AgeInYearsAt(start of LCE."Measurement Period") between 50 and 80
  AgeInYears() >= 50 and AgeInYears() <= 80

// Age range for CMS Medicare eligibility
define "Age 55 through 80":
  AgeInYears() >= 55 and AgeInYears() <= 80
