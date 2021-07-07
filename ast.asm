%define MINUS_ASCII_CODE 45
%define DIGIT_ASCII_START 48

section .data
    delim db " ", 0
section .bss
    root resd 1
    strtok_buffer resd 1

section .text

extern strtok
extern calloc
extern strdup

global create_tree
global iocla_atoi

;; in aceasta functie vom avea o prelucrare a unui sir de caractere intr-un
;; numar intreg
;; @return in registrul eax se returneaza intregul dorit
iocla_atoi:
    push    ebp
    mov     ebp, esp
    ;; punem in registrul esi stringul primit ca parametru al functiei
    mov     esi, [ebp + 8]

    xor     eax, eax
    xor     ecx, ecx        ;; registrul ecx joaca rolul de contor pentru string

    mov     dl, [esi + ecx] ;; luam primul caracter; verificam daca este minus
    cmp     dl, MINUS_ASCII_CODE
    ;; daca nu este minus, atunci incepem direct prelucrarea sirului de caractere
    jne     string_to_integer_conversion
    ;; daca e minus, setam bitul de semn 
    ;; acest bit de semn este retinut in registrul ebx, pe care il folosim
    ;; mai tarziu
    mov     ebx, -1
    inc     ecx             ;; creste ecx, deoarece vrem sa sarim peste "-"    
;; in acest label din cadrul functiei iocla_atoi, vom face o prelucrare a
;; cifrelor din string, similara cu cea din C: vom lua de la stanga la dreapta
;; fiecare cifra si vom forma in eax numarul, prin inmultiri succesive ale lui
;; eax cu 10, si apoi adaugarea urmatoarei cifre
string_to_integer_conversion:
    mov     edx, 10
    ;; dupa operatia de mul, eax = eax * 10
    mul     edx
    ;; luam urmatoarea cifra din string, de la pozitia ecx
    mov     dl, [esi + ecx]
    ;; dl are codul ASCII al respectivei cifre; vrem sa obtinem valoarea reala
    sub     dl, DIGIT_ASCII_START
    ;; obtinem eax curent
    add     eax, edx
    inc     ecx
    ;; daca urmatorul caracter din string este NULL, am terminat programul
    mov     dl, [esi + ecx]
    cmp     dl, 0
    jne     string_to_integer_conversion
    ;; cazul in care numarul este negativ, mai avem un pas de realizat, si anume
    ;; sa facem eax negativ
    cmp     ebx, -1
    jne     finish_iocla_itoa
    mul     ebx
;; label de incheiere al functiei iocla_itoa
finish_iocla_itoa:
    leave
    ret

;; functie care verifica daca o valoare dintr-un nod este operand (+,-,/,*) sau
;; pur si simplu un numar intreg
;; Stim ca in tabelul ASCII, operanzii au codul mai mic decat orice cifra.
;; Implicit, este suficient doar sa verificam daca primul caracter are codul
;; ASCII mai mare decat al lui '0'; de asemenea, mai exista cazul special '-',
;; in care mai facem o verificare in plus (daca urmatorul caracter este NULL,
;; atunci valoarea este un operator, altfel este numar)
;; @return in eax --> 1, daca avem un operator
;;                --> 0, daca avem un numar intreg
check_if_operand:
    push    ebp
    mov     ebp, esp

    mov     edx, [ebp + 8]  ;; aici o sa avem stringul de verificat
    mov     ebx, [edx + 1]  ;; al doilea caracter din string

    mov     edx, [edx]      ;; al doilea caracter din string
    cmp     bl, 0
    ;; daca al doilea caracter nu este NULL, atunci avem numar
    jne     not_an_operand
    mov     eax, 1
    ;; verificam si cazul special, cel cu minus
    cmp     dl, DIGIT_ASCII_START
    jge     not_an_operand
    jmp     finish_check_if_operand
;; cazul in care nu avem operand, intoarcem rezultatul corespunzator
not_an_operand:
    mov     eax, 0
;; label de incheiere a functiei check_if_operand
finish_check_if_operand:
    leave
    ret

;; functie care creeaza un nou nod in arbore
;; intoarce folosind registrul eax rezultatul dorit
;; @return --> un pointer catre nodul creeat, in cazul in care nodul dorit se
;;             poate crea
;;         --> NULL,  in care nu se poate crea un astfel de nod'
;; De mentionat este si faptul ca se aloca memorie si pentru valoarea din nod si
;; se adauga (acel string, care reprezinta fie un operand, fie un nr. intreg)
create_new_node:
    push ebp
    mov ebp, esp
    ;; folosim strtok pentru a obtine valorile ce trebuie atribuite nodului
    push delim
    push dword [strtok_buffer]
    call strtok
    add esp, 8
    ;; daca in urma lui strtok ajungem la NULL, atunci programul se termina
    cmp eax, 0
    je finish_new_node
    push eax
    ;; aici vom aloca memorie efectiva pentru nodul nostru
    push 4                      ;; dimensiunea unui element din nod
    push 3                      ;; numarul de elemente ale nodului
    call calloc
    add esp, 8
    mov edi, [ebp + 8]
    mov [edi], eax
    ;; trebuie sa alocam memorie dinamica (pe heap) pentru a putea stoca valoarea
    ;; stringului obtinut, intrucat nu va putea fi eliberata ulterior, fiind de
    ;; natura statica
    ;; Folosim strdup pentru ca este functia care face atat alocarea de memorie
    ;; (care putea fi facuta cu malloc/calloc), cat si copierea stringului in
    ;; respectiva zona de memorie (care putea fi facuta, de ex, cu memcpy)
    mov edx, [edi]
    pop eax
    push edx
    push eax
    call strdup
    add esp, 4
    pop edx
    mov [edx], eax
    ;; intoarcem rezultatul in eax
    mov eax, edi
;; label ce marcheaza incheierea lui create_new_node;
finish_new_node:
    leave
    ret

;; Probabil cea mai complexa functie din cadrul temei; desi nu pare cine stie ce
;; ea se foloseste de cele de mai sus pentru a putea crea de la 0 arborele dorit
;; Modul de implementare este recursiv, fiind extrem de asemanator cu cel din C
;; ... C is assembly on steroids... Change my mind :))
;; Functia nu returneaza nimic, ea primeste radacina, de la care porneste si
;; creeaza restul arborelui
recursive_tree:
    push ebp
    mov ebp, esp
    ;; vedem daca nodul initial este operand sau nu; nodurile care NU sunt\
    ;; operanzi (implicit cele care sunt numere intregi) sunt noduri frunza
    ;; prin urmare, o sa trebuiasca sa ne intoarcem in functie de conditia asta
    mov edx, [ebp + 8]
    mov edx, [edx]
    mov edx, [edx]
    push edx
    call check_if_operand
    add esp, 4
    cmp eax, 0
    ;; daca avem intreg, iesim din functie, si ne intoarcem la apelul anterior
    ;; (mai exact, apelul care avea nodul parinte)
    je finish_recursive_tree
    ;; daca avem nod terminal si ne aflam in stanga, inseamna ca nu mai are rost
    ;; sa mai continuam pe stanga; ne ducem la cel din dreapta, si daca si aici
    ;; exista deja nod creat, atunci aia e, ne intoarcem la parinte (recursiv)
    mov edx, [ebp + 8]
    mov edx, [edx]
    cmp dword [edx + 4], 0
    jne right_child
;; nasterea unui fiu stanga
left_child:
    mov edx, [ebp + 8]
    mov edx, [edx]
    add edx, 4
    ;; il construim efectiv
    push edx
    call create_new_node
    add esp, 4
    ;; daca avem intreg, ne intoarcem la parinte
    cmp eax, 0
    je finish_recursive_tree
    ;; daca e operand, mergem in adancime cu arborele nostru
    push eax
    call recursive_tree
    add esp, 4
;; facem acelasi lucru si pentru fiul dreapta
right_child:
    mov edx, [ebp + 8]
    mov edx, [edx]
    add edx, 8
    ;; il construim efectiv
    push edx
    call create_new_node
    add esp, 4
    ;; daca avem intreg, ne intoarcem la parinte
    cmp eax, 0
    je finish_recursive_tree
    ;; daca e operand, mergem in adancime cu arborele nostru
    push eax
    call recursive_tree
    add esp, 4
;; label care incheie un apel recursiv (sau functia toata, daca este cazul)
finish_recursive_tree:
    leave
    ret

;;Functia care trebuia implementata; creeaza un arbore (cu tot cu radacina)
;; @return --> in eax, adresa catre nodul radacina
create_tree:
    enter 0, 0
    ;; salvam registrul ebx, ca facea pe nebunul daca ii schimbam valoarea
    push ebx
    mov edx, [ebp + 8]
    ;; in strtok_buffer, prima oara vom avea string-ul pe care il primim ca
    ;; input, anume forma poloneza prefixata, urmand ca mai apoi sa fie NULL (0)
    mov [strtok_buffer], edx
    ;; se creeaza prima oara nodul radacina
    push root
    call create_new_node
    add esp, 4
    ;; setam strtok_buffer la NULL
    mov dword [strtok_buffer], 0
    ;; apelam functia recursiva de construire a arborelui nostru
    push root
    call recursive_tree
    add esp, 4
    ;; mutam in registrul eax adresa radacinii arborelui
    mov eax, [root]

    ;; restauram valoarea initiala a lui ebx, si cam asta a fost
    pop ebx

    leave
    ret