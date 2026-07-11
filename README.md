# takt

**Generyczny silnik kaskadowego przetwarzania hierarchicznego** (cybernetyka / teoria systemów autonomicznych).

` takt ` to abstrakcyjny, generyczny rdzeń wykonawczy do sekwencyjnego stabilizowania i przetwarzania n-warstwowych (n ≥ 2) hierarchicznych struktur stanu.

- Transport informacji w pionie i poziomie: **fala** (fale zstępujące / wstępujące).
- Fuzja sygnałów i redukcja entropii: **splot**.
- Zero wiedzy domenowej — czysty silnik cybernetyczny.

## Architektura (jeden takt)

1. Próbkowanie stanu (`fala`)
2. Generowanie surowych sygnałów (detektory + efektory)
3. Fuzja i redukcja przez `splot` → czysty **Wektor Aberracji (ErrorSignal)**
4. Reakcja:
   - Próg przekroczony → **Impuls Wykonawczy (Actuation)**
   - Nieredukowalna entropia / niska pewność → **Interlokacja (SafetyInterlock)** + telemetria na fali wstępującej

## Kluczowe abstrakcje

| Nazwa                    | Opis |
|--------------------------|------|
| `StateNode`              | Abstrakcyjny węzeł drzewa stanu (relacje rodzic-dziecko) |
| `ControlledPlant`        | Środowisko z `sequential_scan()` (generuje takt zegara) |
| `Homeostat`              | Zmienne krytyczne, progi tolerancji, cutoff, entropy_threshold |
| `SplotFusionUnit`        | Redukcja sygnałów przez `splot` |
| `CascadeRegulator`       | Pojedyncza pętla sterowania (L0 … Ln-1), `evaluate()`, parent/child |
| `TaktSequencer`          | Dyskretny zegar — jeden węzeł = jeden takt |
| `FalaWave` / `ErrorSignal` / `Actuation` / `SafetyInterlock` | Struktury sygnałowe |

## Instalacja (dla deweloperów)

```bash
uv sync --dev
uv run pytest
```

Zależności:
- `fala-runtime` (editable)
- `splot-runtime` (editable)

## Użycie (przykład z czystym drzewem matematycznym)

```python
from takt import (
    Homeostat, EssentialVariable,
    MathTreePlant, TreeNode,
    CascadeRegulator, TaktSequencer,
)

h = Homeostat(0)
h.add_variable(EssentialVariable("dev", tolerance=0.1))

reg = CascadeRegulator(layer=0, homeostat=h)
plant = MathTreePlant(TreeNode("root", 0.0, (TreeNode("n0", 0.7),)))

seq = TaktSequencer(plant, reg)
seq.run_one_tact()           # root
result = seq.run_one_tact()  # n0

print(result.signals.actuation)   # Actuation lub SafetyInterlock
```

## Testy

Wszystkie testy używają wyłącznie mockowych drzew liczbowych — zero zewnętrznych API.

```bash
uv run pytest -q
```

## Filozofia

- **Strict fail-closed**: brak redukcji entropii poniżej progu → interlock, nigdy niepewna akcja.
- Modularność i testowalność.
- Nazewnictwo zgodne z polską terminologią cybernetyczną (Marian Mazur i następcy).

## Zależności

- [fala](https://github.com/mikolaj92/Fala) — transport impulsów i korelacji
- [splot](https://github.com/mikolaj92/splot) — arbitraż i redukcja entropii

## Licencja

MIT
