# Współbieżny Szesnastkator Noteć

Zaimplementuj w asemblerze x86_64 moduł Współbieżnego Szesnastkatora Noteć wykonującego obliczenia na 64-bitowych liczbach zapisywanych przy podstawie 16 i używającego odwrotnej notacji polskiej. Można uruchomić `N` działających równolegle instancji Notecia, numerowanych od `0` do `N − 1`, gdzie `N` jest parametrem kompilacji. Każda instancja Notecia wywoływana jest z języka C w osobnym wątku za pomocą funkcji:
```
uint64_t notec(uint32_t n, char const *calc);
```
Parametr `n` zawiera numer instancji Notecia. Parametr `calc` jest wskaźnikiem na napis ASCIIZ i opisuje obliczenie, jakie ma wykonać Noteć. Obliczenie składa się z operacji wykonywanych na stosie, który na początku jest pusty. Znaki napisu interpretujemy następująco:

* `0` do `9`, `A` do `F`, `a` do `f` – Znak jest interpretowany jako cyfra w zapisie przy podstawie 16. Jeśli Noteć jest w trybie wpisywania liczby, to liczba na wierzchołku stosu jest przesuwana o jedną pozycję w lewo i uzupełniania na najmniej znaczącej pozycji podaną cyfrą. Jeśli Noteć nie jest w trybie wpisywania liczby, to na wierzchołek stosu jest wstawiana wartość podanej cyfry. Noteć przechodzi w tryb wpisywania liczby po wczytaniu jednego ze znaków z tej grupy, a wychodzi z trybu wpisywania liczby po wczytaniu dowolnego znaku nie należącego do tej grupy.

* `=` – Wyjdź z trybu wpisywania liczby.

* `+` – Zdejmij dwie wartości ze stosu, oblicz ich sumę i wstaw wynik na stos.

* `*` – Zdejmij dwie wartości ze stosu, oblicz ich iloczyn i wstaw wynik na stos.

* `-` – Zaneguj arytmetycznie wartość na wierzchołku stosu.

* `&` – Zdejmij dwie wartości ze stosu, wykonaj na nich operację `AND` i wstaw wynik na stos.

* `|` – Zdejmij dwie wartości ze stosu, wykonaj na nich operację `OR` i wstaw wynik na stos.

* `^` – Zdejmij dwie wartości ze stosu, wykonaj na nich operację `XOR` i wstaw wynik na stos.

* `~` – Zaneguj bitowo wartość na wierzchołku stosu.

* `Z` – Usuń wartość z wierzchołka stosu.

* `Y` – Wstaw na stos wartość z wierzchołka stosu, czyli zduplikuj wartość na wierzchu stosu.

* `X` – Zamień miejscami dwie wartości na wierzchu stosu.

* `N` – Wstaw na stos liczbę Noteci.

* `n` – Wstaw na stos numer instancji tego Notecia.

* `g` – Wywołaj (zaimplementowaną gdzieś indziej w języku C lub Asemblerze) funkcję:
```
    int64_t debug(uint32_t n, uint64_t *stack_pointer);
```
    Parametr `n` zawiera numer instancji Notecia wywołującego tę funkcję. Parametr `stack_pointer` wskazuje na wierzchołek stosu Notecia. Funkcja `debug` może zmodyfikować stos. Wartość zwrócona przez tę funkcję oznacza, o ile pozycji należy przesunąć wierzchołek stosu po jej wykonaniu.

* `W` – Zdejmij wartość ze stosu, potraktuj ją jako numer instancji Notecia `m`. Czekaj na operację `W` Notecia `m` ze zdjętym ze stosu numerem instancji Notecia `n` i zamień wartości na wierzchołkach stosów Noteci `m` i `n`.

Po zakończeniu przez Notecia wykonywania obliczenia jego wynikiem, czyli wynikiem funkcji `notec`, jest wartość z wierzchołka stosu. Wszystkie operacje wykonywane są na liczbach 64-bitowych modulo `2^64`. Zakładamy, że obliczenie jest poprawne, tzn. zawiera tylko opisane wyżej znaki, kończy się zerowym bajtem, nie próbuje sięgać po wartość z pustego stosu i nie doprowadza do zakleszczenia. Zachowanie Notecia dla niepoprawnego obliczenia jest niezdefiniowane.

Sformułowania „zdejmij dwie wartości ze stosu”, „wstaw wynik na stos” itp. opisują semantykę operacji, a nie konieczność wykonania akurat takich operacji na stosie.

## Oddawanie rozwiązania i kompilowanie

Jako rozwiązanie należy wstawić w Moodle plik o nazwie `notec.asm`. Rozwiązanie będzie asemblowane na maszynie `students.mimuw.edu.pl` poleceniem:
```
nasm -DN=$N -f elf64 -w+all -w+error -o notec.o notec.asm
```
Przykład kompiluje się i linkuje poleceniami:
```
gcc -DN=$N -c -Wall -Wextra -O2 -std=c11 -o example.o example.c
gcc notec.o example.o -lpthread -o example
```
W powyższych poleceniach zmienna `$N` określa wartość parametru `N`.
## Pozostałe wymagania

Jako stosu, którego do opisanych wyżej obliczeń używa Noteć, należy użyć sprzętowego stosu procesora. Nie należy zakładać żadnych górnych ograniczeń na wartość `N` i rozmiar stosu, innych niż wynikające z architektury procesora i dostępnej pamięci. Nie wolno korzystać z żadnych bibliotek. Synchronizację wątków należy zaimplementować za pomocą jakiegoś wariantu wirującej blokady. Uwaga: można to zrobić bez konieczności blokowania szyny pamięci za pomocą `lock`.
