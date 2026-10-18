# 앱과 SAP ECC 연동

이 프로토타입은 인메모리(In-memory) 샘플 데이터로 구동됩니다. 모든 데이터 접근은 `webapp/model/PALogic.js` 를 거쳐서 이루어지며,컨트롤러와 뷰는 스토리지(데이터 저장소)에 직접 접근하지 않습니다. 
시스템을 실운영(Go-live) 환경으로 전환하려면, ECC Gateway가 제공하는 OData V2 서비스상에서 이 모듈의 함수들을 다시 구현하되 기존 함수의 시그니처(파라미터 및 반환 구조)를 그대로 유지하면 됩니다.

> 상태: 아래에 명시된 오브젝트 이름들은 **제안 사항(Proposal)** 입니다. ECC 시스템을 대상으로 실제로
> 실행된 적은 없습니다(접근 가능한 ECC 환경이 없었음).
> 구현하기 전에 해당 SAP 릴리스의 FM/BAPI 이름, 파라미터 및 커스터마이징(설정) 테이블을 반드시 확인하십시오.

## 1. 아키텍처 (Architecture)

```
브라우저 (본 앱)  --HTTPS-->  BTP Destination (Cloud Connector)  -->  ECC Gateway (SEGW, OData V2)
                                                                        -->  HR 기능 모듈 / BAPIs
```

* ECC가 온프레미스(On-premise)에 있는 경우: **Cloud Connector** 와 BTP **Destination** 을 통해 외부로 노출하되,
  Principal Propagation(사용자 신원 전파) 방식을 권장합니다.
  이를 통해 ECC 권한(P_ORGIN, P_ORGINCON, P_PERNR)이 실제 접속한 사용자에게 그대로 적용되도록 합니다.
* 광범위한 HR 권한을 가진 기술 사용자(Technical User) 계정으로 **연동하지 마십시오.**

## 2. 제안하는 OData V2 모델 (SEGW 프로젝트 `ZHR_PA`)

| Entity set | Key | Purpose | Maps to PALogic |
|---|---|---|---|
| `EmployeeSet` | Pernr, KeyDate | 직원 검색 및 헤더 정보 | `searchEmployees`, `getEmployee` |
| `InfotypeRecordSet` | Pernr, Infty, Subty, Objps, Sprps, Endda, Begda, Seqnr | 인포타입 레코드 행(Row) 단위 관리; 인포타입별로 범용 필드백(Field bag) 또는 고정 타입 엔티티 형태로 구성 | `getRecords`, `getRecord`, `create`, `change`, `delimit`, `remove` |
| `ActionSet` (function import `ExecuteAction`) | Massn, Pernr, Begda, Massg + infotype payloads | 트랜잭션 단위의 인사발령; '원 콜(One call)'로 전체 커밋(Commit) 또는 롤백(Rollback) 처리 | `executeAction`, `actionDefaults` |
| `LockSet` | Pernr | 레코드 잠금(Enqueue) 및 잠금 해제(Dequeue) | `lock`, `unlock`, `getLock` |
| `ValueHelp*Set` | Key, Text | 커스터마이징 데이터의 값 도움말(Value help) | `infotypes.js` LISTS |

인포타입 별 고정타입 엔티티(Infotype0001, Infotype0002, ...)를 사용하는 것이 유연한 필드백(Field bag) 구조를 쓰는 것보다
보안 통제 및 데이터 유효성 검증 측면에서 더 수월합니다.

## 3. 검토 대상 백엔드 빌딩 블록 (사용 중인 SAP 시스템에서 검증 필요)

| Need | Candidate | Note |
|---|---|---|
| Read infotype | `HR_READ_INFOTYPE` | 내부에서 P_PERNR 검사를 통해 권한 제어가 동작하는지 확인이 필요합니다. 확실하지 않다면 HR_CHECK_AUTHORITY_INFTY를 명시적으로 호출하십시오. |
| Enqueue employee | `HR_EMPLOYEE_ENQUEUE` / `BAPI_EMPLOYEE_ENQUEUE` | 작업 완료 후 이와 쌍을 이루는 DEQUEUE 함수를 통해 잠금을 해제해야 합니다. |
| Insert / change / delimit / delete | `HR_INFOTYPE_OPERATION` | INS, MOD, DEL, COP, LIS9 등의 오퍼레이션을 지원합니다. PA30 트랜잭션의 시간 제약(Time-Constraint) 로직을 그대로 적용해 줍니다. 현재 `PALogic.js` 에 구현된 목업이 바로 이 동작을 모방하고 있습니다. |
| Personnel action (0000/0302) | PA40 logic, `HR_MAINTAIN_MASTERDATA` | 본 프로토타입의 PA30 영역에서 인포타입 0000은 조회 전용입니다. 모든 발령은 `executeAction` 을 통해 구동됩니다. ECC에서는 발령 유형에 따라 정보 그룹(Info Group: T588D/T588Z, 피처 MNMAC, T529A/T529T, T530)이 결정되지만, 프로토타입은 `infotypes.js` (`ACTIONS`) 에 3가지 발령을 하드코딩해 두었습니다. |
| New personnel number | number range object `PREL` (`NUMBER_GET_NEXT`) or `HR_MAINTAIN_MASTERDATA` with an empty PERNR | 프로토타입에서는 현재 사원번호 최대값 + 1 방식으로 임시 채번합니다. |
| Value helps | tables T529A/T530 (actions/reasons), T500P/T001P (areas), T503K (employee subgroup), T005 (countries), T591A (subtypes) | RFC 호출 또는 Gateway의 CDS 기반 읽기 기능을 통해 데이터를 가져옵니다. |

## 4. 앱 내에서 교체해야 할 항목

1. `model/PALogic.js`: 각 함수가 `ODataModel` (V2) 호출 구조로 전환되어야 합니다.
   기존과 동일한 형태의 반환 값(`{ok, errors:[{code,params}]}`)을 유지해야 하며, ECC 메시지(BAPIRET2 또는 `/IWBEP/CX_MGW_BUSI_EXCEPTION`)를 기존 오류 코드와 매핑하거나
   두 i18n 파일에 새로운 `msg_*` 키를 추가해야 합니다. 함수들이 비동기(Promise) 방식으로 바뀌므로, 컨트롤러 내 동기 호출부들을 `.then(...)` 구조로 수정해야 합니다.
   (수정 대상은 화면을 새로고침하는 `_refresh`, 다이얼로그의 저장 핸들러, 그리고 `onToggleEdit` 함수뿐입니다.)
3. `model/infotypes.js`: 기존 샘플 값인 `LISTS` 를 제거하고, 실제 Gateway 서비스로부터 값 도움말을 로드하도록 수정합니다.
   (`fields` 메타데이터 구조는 그대로 유지하거나 `$metadata` 로부터 파생하여 동적 생성할 수 있습니다.)
5. `model/MockData.js`: 더 이상 필요하지 않으므로 삭제합니다.
6. 서비스 연동 정보를 `manifest.json` (`sap.app.dataSources`)에 추가하고, 라우팅을 위한 Destination 설정을 `xs-app.json` 및 `ui5.yaml` 파일에 등록합니다.

## 5. 보안 및 컴플라이언스 체크리스트

* 인사(HR) 데이터는 민감한 개인정보입니다. 최소 권한 원칙을 적용하고 데이터 변경 이력을 로깅하십시오. (ECC 인포타입 변경 로그 기능 또는 리포트 RPUAUD00 활용).
* 조회 전용(PA20)과 유지보수(PA30) 역할을 분리하여 운영하십시오: Gateway단에서는 단순히 트랜잭션 코드(S_TCODE) 제어만으로는 부족하므로,
  ABAP 백엔드 구현부에서 `P_ORGIN` 권한(AUTHC = R 또는 W)을 반드시 직접 검증해야 합니다.
* 운영용(Production) 빌드 이미지나 배포 파일에 샘플 데이터가 포함되지 않도록 관리하십시오.
* 실제 환경의 복잡한 날짜 기준 이력 데이터를 바탕으로 철저히 테스트하십시오(TC2 인포타입의 이력 공백, 미래 일자 레코드, 퇴사자, 재입사자 시나리오 등).

## 6. 프로토타입에 적용된 기지(Known)의 단순화 사항

* 인포타입 0000은 PA30 메뉴에서 조회 전용으로만 작동합니다. PA40 발령 영역은 단 3가지 발령 유형만 지원하며, 발령 유형과 사유 간의 종속 관계(T530) 및 고용 상태에 따른 정보 그룹 변형 규칙(피처 MNMAC / T588Z 동적 액션 등)은 구현되어 있지 않습니다.
* "0000 인포타입은 수정 불가"라는 규칙 외에는 별도의 권한 오브젝트 제어가 없으며, 국가별 화면 특화 로직(MOLGA 관련)도 제외되어 있습니다.
* 사용자는 단 한 명(`DEMO_USER`)으로 고정되어 있으며, 사원번호 10000004번에 대해서만 다른 사용자가 잠근 상황을 모방하도록 가상 잠금 로직이 심어져 있습니다.
* UI상에서 "강제 잠금 해제" 기능은 제공하지 않으며, 변경 이력 관리 역시 "수정자 / 수정일자" 수준의 단순 기록만 지원합니다.
