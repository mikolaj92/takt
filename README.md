# takt

**Generyczny mechanizm kaskadowego sterowania cybernetycznego (Hierarchical Orchestrator).**

`takt` to abstrakcyjny, w 100% generyczny silnik do sekwencyjnego stabilizowania i regulacji **dowolnych** n-warstwowych (n ≥ 2) hierarchicznych struktur stanu.

Działa identycznie nad:
- drzewem zdań i akapitów dokumentu tekstowego,
- drzewem plików, modułów i linijek kodu źródłowego (np. Pull Request na GitHubie),
- drzewem wierszy, tabel i sekcji karty charakterystyki chemicznej (SDS),
- dowolnym innym drzewem stanów (graf zależności, stan agenta, konfiguracja systemu, cokolwiek).

Nie jest parserem formatów plików ani silnikiem kolejkowym.  
Jest nakładką sterowania kaskadowego, która dostarcza **pionowy przepływ sygnałów** i redukcję entropii nad dowolnym drzewem kontrolowanym.

- Transport pionowy i poziomy: **fala** (zawsze wymagana jako podłoże transportu).
- Unifikacja i redukcja entropii: **splot** (opcjonalny — domyślny reduktor w SplotFusionUnit; można podmieniać lub pomijać).
- Zero wiedzy domenowej — czysty mechanizm cybernetyczny.

## PR Review jako przykład kaskady (n=4)

```
L3  Globalne repozytorium / architektura
    ↓ fala zstępująca: "tylko asynchroniczny dostęp do bazy"
L2  Pull Request jako całość (kontekst biznesowy)
L1  Plik / moduł
L0  Linijka / diff hunk   ← takt przesuwa okno próbkowania takt po takcie
```

Na poziomie L0 detektor widzi `db.execute(...)`.  
Dzięki fali zstępującej z L3 wie o globalnej zasadzie.  
Generuje sygnał aberracji.  
Splot unifikuje odczyty z wielu detektorów.  
Jeśli pewność wysoka i poza progiem homeostatycznym → Actuation (np. blokada PR).

Dokładnie ten sam mechanizm działa dla dokumentów, SDS, grafów zależności itd.

## Architektura (jeden takt)

1. Próbkowanie stanu (`fala`)
2. Generowanie surowych sygnałów (detektory + efektory)
3. Fuzja i redukcja przez `splot` → czysty **Wektor Aberracji (ErrorSignal)**
4. Reakcja:
   - Próg przekroczony → **Impuls Wykonawczy (Actuation)**
   - Nieredukowalna entropia / niska pewność → **Interlokacja (SafetyInterlock)** + telemetria na fali wstępującej

## Dowolne środowisko kontrolowane (Plant)

`StateNode` + `ControlledPlant.sequential_scan()` to jedyne, co takt widzi.

Kolejny węzeł = jeden takt zegara.

To może być dowolna hierarchia:
- dokument (ReviewKit)
- kod źródłowy i diffy (PRKit)
- dane chemiczne (SDSKit)
- graf zależności
- stan dowolnego systemu

Wszystkie zewnętrzne "Kity" robią to samo: implementują `ControlledPlant` dla swojego kształtu drzewa i tłumaczą węzły na akcje w świecie zewnętrznym (fala, GitHub, pliki, API...).

Sam takt pozostaje całkowicie odcięty od domeny.

## Kluczowe abstrakcje

| Nazwa                    | Opis |
|--------------------------|------|
| `StateNode`              | Abstrakcyjny węzeł drzewa stanu (relacje rodzic-dziecko) |
| `ControlledPlant`        | Środowisko z `sequential_scan()` (generuje takt zegara) |
| `ProfilHomeostatyczny`   | Profil stabilności warstwy: zmienne krytyczne, progi, cutoff, entropy_threshold (NIE mylić z runtime gate z Fala) |
| `SplotFusionUnit`        | Redukcja sygnałów przez `splot` |
| `CascadeRegulator`       | Pojedyncza pętla sterowania (L0 … Ln-1), `evaluate()`, parent/child |
| `TaktSequencer`          | Dyskretny zegar — jeden węzeł = jeden takt |
| `FalaWave` / `ErrorSignal` / `Actuation` / `SafetyInterlock` | Struktury sygnałowe |

## Instalacja (dla deweloperów)

```bash
uv sync --dev
uv run pytest
```

- `fala-runtime` (editable, wymagane)
- `splot-runtime` (editable, opcjonalne — `pip install -e .[splot]` lub uv z grupy extra)
## Użycie (przykład z czystym drzewem matematycznym)

Poniższy przykład używa wyłącznie liczb, żeby pokazać, że takt nie zawiera żadnej wiedzy domenowej. W rzeczywistym zastosowaniu przekazujesz własne drzewo stanu — strukturę kodu, dokument, dane SDS, graf zależności, stan agenta, cokolwiek.

```python
from takt import (
    ProfilHomeostatyczny, EssentialVariable,
    MathTreePlant, TreeNode,
    CascadeRegulator, TaktSequencer,
):

h = ProfilHomeostatyczny(0)
h.add_variable(EssentialVariable("dev", tolerance=0.1))

reg = CascadeRegulator(layer=0, homeostat=h)
plant = MathTreePlant(TreeNode("root", 0.0, (TreeNode("n0", 0.7),)))

seq = TaktSequencer(plant, reg)
seq.run_one_tact()           # root
result = seq.run_one_tact()  # n0

print(result.signals.actuation)   # Actuation lub SafetyInterlock
```

## Testy

Wszystkie testy używają wyłącznie mockowych drzew liczbowych. Zero zewnętrznych API i zero założeń domenowych.

```bash
uv run pytest -q
```

## Filozofia

- **Strict fail-closed** — jeśli `splot` nie jest w stanie zredukować entropii poniżej progu zdefiniowanego w `ProfilHomeostatycznym`, system nie ma prawa wykonać impulsu wykonawczego.
- **Pełna generyczność** — takt działa nad dowolnym drzewem stanu. Kod źródłowy, dokument tekstowy, dane chemiczne, graf zależności, stan agenta — to tylko różne implementacje `ControlledPlant`.
- **Kaskada, nie płaska pętla** — fala + takt dostarczają pionowego przepływu ograniczeń (fala zstępująca) i telemetrii (fala wstępująca) między warstwami. Fala sama w sobie jest płaska (poziome conduction). Takt nakłada na nią strukturę n-warstw.
- Modularność i testowalność.
- Nazewnictwo zgodne z polską terminologią cybernetyczną (Marian Mazur i następcy).

## Rola Taktu w ekosystemie

- `fala` = niezawodny, płaski runtime impulsów, procesów i poziomego conduction (takt zawsze na nim stoi).
- `splot` = uniwersalny filtr decyzyjny (redukcja entropii) — domyślna implementacja w SplotFusionUnit; można zastąpić własną strategią oceny.
- `takt` = generyczny manager kaskady, który:
  - przyjmuje dowolne drzewo (`StateNode` + `ControlledPlant`),
  - zarządza n warstwami regulatorów z `ProfilHomeostatycznym`,
  - wstrzykuje kontekst (w tym zewnętrzny cel/referencję) przez fale zstępujące,
  - używa reduktora entropii (domyślnie splot) przed każdym taktem,
  - dąży do homeostazy warstwy i całej kaskady.
ReviewKit, SDSKit, PRKit itp. to tylko zewnętrzne adaptery, które uczą takt "rozmawiać" z konkretnym kształtem drzewa. Core `takt` pozostaje uniwersalny.

## Zależności

- [fala](https://github.com/mikolaj92/Fala) — płaski, niezawodny runtime impulsów i poziome conduction
- [splot](https://github.com/mikolaj92/splot) — uniwersalny filtr decyzyjny

## Licencja

MIT
