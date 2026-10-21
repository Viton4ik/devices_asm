
default rel

extern GetStdHandle
extern WriteConsoleW
extern ReadConsoleW
extern ExitProcess
extern SetupDiGetClassDevsW
extern SetupDiEnumDeviceInfo
extern SetupDiGetDeviceRegistryPropertyW
extern SetupDiGetDeviceInstanceIdW
extern SetupDiDestroyDeviceInfoList

global main

section .data

title:
    db __utf16le__('=== ИНВЕНТАРИЗАЦИЯ УСТРОЙСТВ WINDOWS ==='),0,0,13,0,10,0,13,0,10,0

section1:
    db __utf16le__('=== 1. УСТРОЙСТВА С ПОТЕНЦИАЛЬНЫМ ПРОГРАММНЫМ УПРАВЛЕНИЕМ ==='),0,0,13,0,10,0

section2:
    db __utf16le__('=== 2. ОСТАЛЬНЫЕ СИСТЕМНЫЕ И PNP-УСТРОЙСТВА ==='),0,0,13,0,10,0

device_title:
    db __utf16le__('--- Устройство ---'),0,0,13,0,10,0

name_label:
    db __utf16le__('Имя: '),0,0
desc_label:
    db __utf16le__('Описание: '),0,0
mfg_label:
    db __utf16le__('Производитель: '),0,0
class_label:
    db __utf16le__('Класс Windows: '),0,0
hw_label:
    db __utf16le__('Hardware ID: '),0,0
id_label:
    db __utf16le__('Instance ID: '),0,0
explain_label:
    db __utf16le__('Пояснение: '),0,0

unavailable:
    db __utf16le__('(свойство недоступно)'),0,0

ex_net:
    db __utf16le__('Сетевой адаптер. Сетевые операции доступны через Winsock и сетевые API Windows; низкоуровневое управление зависит от драйвера.'),0,0
ex_ports:
    db __utf16le__('Последовательный порт или COM-устройство. Обычно доступно через CreateFile и функции настройки последовательного порта.'),0,0
ex_usb:
    db __utf16le__('USB-устройство или контроллер. Управление зависит от драйвера, протокола устройства и доступного интерфейса, например WinUSB.'),0,0
ex_hid:
    db __utf16le__('Устройство ввода класса HID. Для чтения данных обычно используется Windows HID API; доступные операции зависят от устройства.'),0,0
ex_media:
    db __utf16le__('Аудио- или мультимедийное устройство. Обычно используется Windows Core Audio, Multimedia API или интерфейс драйвера.'),0,0
ex_image:
    db __utf16le__('Устройство захвата изображения, камера или сканер. Возможен доступ через Media Foundation, Windows Camera API или WIA.'),0,0
ex_bt:
    db __utf16le__('Bluetooth-устройство. Возможен доступ через Bluetooth API Windows; конкретные функции зависят от профиля и устройства.'),0,0
ex_storage:
    db __utf16le__('Накопитель или контроллер хранения данных. Доступ возможен через файловые API, Storage API и DeviceIoControl с учётом прав.'),0,0
ex_portable:
    db __utf16le__('Портативное устройство. Для взаимодействия могут использоваться Windows Portable Devices API или протокол производителя.'),0,0
ex_input:
    db __utf16le__('Устройство ввода. Для получения событий могут использоваться Raw Input и HID API; прямое управление ограничено Windows и драйвером.'),0,0
ex_monitor:
    db __utf16le__('Монитор или устройство отображения. Часть параметров доступна через Windows Display API; дополнительные функции зависят от устройства.'),0,0
ex_biometric:
    db __utf16le__('Биометрическое устройство. Доступ обычно осуществляется через Windows Biometric Framework и соответствующий драйвер.'),0,0
ex_generic:
    db __utf16le__('Класс потенциально доступен программно, но конкретные операции требуют подходящего Windows API, драйвера или протокола устройства.'),0,0

ex_system:
    db __utf16le__('Системное устройство или ресурс ACPI. Обычно обслуживается Windows и системными драйверами; произвольное прямое управление может быть недоступно.'),0,0
ex_other:
    db __utf16le__('Служебное, виртуальное или другое PnP-устройство. Возможность управления зависит от назначения, драйвера и наличия документированного API.'),0,0

done_text:
    db 13,0,10,0
    db __utf16le__('Перечисление завершено. Нажми Enter, чтобы закрыть программу.'),0,0
    db 13,0,10,0

error_text:
    db __utf16le__('Ошибка: Windows не смогла получить список PnP-устройств.'),0,0,13,0,10,0

newline:
    db 13,0,10,0,0,0

section .bss

g_devset       resq 1
g_devinfo      resb 32
g_index        resd 1
g_pass         resd 1
g_prop_id      resd 1
g_label        resq 1

prop_type      resd 1
required_size  resd 1
chars_read     resd 1

prop_buf       resb 2048
class_buf      resb 512
instance_buf   resb 2048
input_buf      resw 4

section .text

; RCX = UTF-16 string pointer
print_z:
    sub rsp, 56
    mov rdx, rcx
    xor r10d, r10d

.scan:
    cmp r10d, 1024
    jae .emit
    cmp word [rdx+r10*2], 0
    je .emit
    inc r10d
    jmp .scan

.emit:
    mov [rsp+40], rdx
    mov [rsp+48], r10d
    mov rcx, [rsp+40]
    mov edx, [rsp+48]
    call print_n
    add rsp, 56
    ret

; RCX = UTF-16 string, EDX = number of UTF-16 characters
print_n:
    sub rsp, 56
    mov [rsp+40], rcx
    mov [rsp+48], edx

    mov ecx, -11
    call GetStdHandle

    mov rcx, rax
    mov rdx, [rsp+40]
    mov r8d, [rsp+48]
    lea r9, [rsp+24]
    mov qword [rsp+32], 0
    call WriteConsoleW

    add rsp, 56
    ret

; Get a device registry property.
; RCX = HDEVINFO, RDX = SP_DEVINFO_DATA, R8D = property ID
; Output: EAX = success flag; data in prop_buf
get_property:
    sub rsp, 56

    mov word [rel prop_buf], 0
    mov dword [rel prop_type], 0
    mov dword [rel required_size], 0

    lea r9, [rel prop_type]
    lea rax, [rel prop_buf]
    mov [rsp+32], rax
    mov qword [rsp+40], 2048
    lea rax, [rel required_size]
    mov [rsp+48], rax

    call SetupDiGetDeviceRegistryPropertyW

    add rsp, 56
    ret

; Copy the class property from prop_buf to class_buf.
copy_class:
    lea r10, [rel prop_buf]
    lea r11, [rel class_buf]
    xor ecx, ecx

.copy:
    mov ax, [r10+rcx*2]
    mov [r11+rcx*2], ax
    test ax, ax
    jz .finished
    inc ecx
    cmp ecx, 255
    jb .copy

    mov word [r11+510], 0

.finished:
    ret

; Return EAX=1 for potentially manageable classes, otherwise EAX=0.
; This is a heuristic based on the Windows device class.
is_managed:
    ; Net
    cmp word [rel class_buf], 'N'
    jne .ports
    cmp word [rel class_buf+2], 'e'
    jne .ports
    cmp word [rel class_buf+4], 't'
    je .yes

.ports:
    ; Ports, Printer
    cmp word [rel class_buf], 'P'
    jne .usb
    cmp word [rel class_buf+2], 'o'
    jne .printer
    cmp word [rel class_buf+4], 'r'
    je .yes
    jmp .usb

.printer:
    cmp word [rel class_buf+2], 'r'
    jne .usb
    cmp word [rel class_buf+4], 'i'
    je .yes

.usb:
    ; USB
    cmp word [rel class_buf], 'U'
    jne .hid
    cmp word [rel class_buf+2], 'S'
    jne .hid
    cmp word [rel class_buf+4], 'B'
    je .yes

.hid:
    ; HIDClass
    cmp word [rel class_buf], 'H'
    jne .media
    cmp word [rel class_buf+2], 'I'
    jne .media
    cmp word [rel class_buf+4], 'D'
    je .yes

.media:
    ; MEDIA
    cmp word [rel class_buf], 'M'
    jne .image
    cmp word [rel class_buf+2], 'E'
    jne .mouse
    cmp word [rel class_buf+4], 'D'
    je .yes
    jmp .image

.mouse:
    ; Mouse, Modem, Monitor
    cmp word [rel class_buf+2], 'o'
    jne .image
    mov ax, [rel class_buf+4]
    cmp ax, 'u'
    je .yes
    cmp ax, 'd'
    je .yes
    cmp ax, 'n'
    je .yes

.image:
    ; Image
    cmp word [rel class_buf], 'I'
    jne .bluetooth
    cmp word [rel class_buf+2], 'm'
    jne .bluetooth
    cmp word [rel class_buf+4], 'a'
    je .yes

.bluetooth:
    ; Bluetooth, Biometric
    cmp word [rel class_buf], 'B'
    jne .disk
    cmp word [rel class_buf+2], 'l'
    jne .biometric
    cmp word [rel class_buf+4], 'u'
    je .yes
    jmp .disk

.biometric:
    cmp word [rel class_buf+2], 'i'
    jne .disk
    cmp word [rel class_buf+4], 'o'
    je .yes

.disk:
    ; DiskDrive
    cmp word [rel class_buf], 'D'
    jne .keyboard
    cmp word [rel class_buf+2], 'i'
    jne .keyboard
    cmp word [rel class_buf+4], 's'
    je .yes

.keyboard:
    ; Keyboard
    cmp word [rel class_buf], 'K'
    jne .camera
    cmp word [rel class_buf+2], 'e'
    jne .camera
    cmp word [rel class_buf+4], 'y'
    je .yes

.camera:
    ; Camera, CDROM
    cmp word [rel class_buf], 'C'
    jne .wpd
    cmp word [rel class_buf+2], 'a'
    jne .cdrom
    cmp word [rel class_buf+4], 'm'
    je .yes
    jmp .wpd

.cdrom:
    cmp word [rel class_buf+2], 'D'
    jne .wpd
    cmp word [rel class_buf+4], 'R'
    je .yes

.wpd:
    ; WPD
    cmp word [rel class_buf], 'W'
    jne .volume
    cmp word [rel class_buf+2], 'P'
    jne .volume
    cmp word [rel class_buf+4], 'D'
    je .yes

.volume:
    ; Volume
    cmp word [rel class_buf], 'V'
    jne .audio
    cmp word [rel class_buf+2], 'o'
    jne .audio
    cmp word [rel class_buf+4], 'l'
    je .yes

.audio:
    ; AudioEndpoint / other Audio classes
    cmp word [rel class_buf], 'A'
    jne .scsi
    cmp word [rel class_buf+2], 'u'
    jne .scsi
    cmp word [rel class_buf+4], 'd'
    je .yes

.scsi:
    ; SCSIAdapter
    cmp word [rel class_buf], 'S'
    jne .no
    cmp word [rel class_buf+2], 'C'
    jne .no
    cmp word [rel class_buf+4], 'S'
    je .yes

.no:
    xor eax, eax
    ret

.yes:
    mov eax, 1
    ret

; Print one device property.
; RCX = label address, EDX = SPDRP property ID
print_property:
    sub rsp, 40

    mov [rel g_label], rcx
    mov [rel g_prop_id], edx

    call print_z

    mov rcx, [rel g_devset]
    lea rdx, [rel g_devinfo]
    mov r8d, [rel g_prop_id]
    call get_property

    test eax, eax
    jz .missing

    lea rcx, [rel prop_buf]
    call print_z
    jmp .end

.missing:
    lea rcx, [rel unavailable]
    call print_z

.end:
    lea rcx, [rel newline]
    call print_z

    add rsp, 40
    ret

; Print the device instance ID.
print_instance:
    sub rsp, 40

    lea rcx, [rel id_label]
    call print_z

    mov rcx, [rel g_devset]
    lea rdx, [rel g_devinfo]
    lea r8, [rel instance_buf]
    mov r9d, 1024
    lea rax, [rel required_size]
    mov [rsp+32], rax
    call SetupDiGetDeviceInstanceIdW

    test eax, eax
    jz .missing

    lea rcx, [rel instance_buf]
    call print_z
    jmp .end

.missing:
    lea rcx, [rel unavailable]
    call print_z

.end:
    lea rcx, [rel newline]
    call print_z

    add rsp, 40
    ret

; Print a Russian explanation based on the class and current pass.
print_explanation:
    sub rsp, 40

    lea rcx, [rel explain_label]
    call print_z

    ; For the second section, use system/other explanations.
    cmp dword [rel g_pass], 1
    jne .managed

    cmp word [rel class_buf], 'S'
    jne .other
    cmp word [rel class_buf+2], 'y'
    jne .other
    cmp word [rel class_buf+4], 's'
    jne .other

    lea rcx, [rel ex_system]
    call print_z
    jmp .end

.other:
    lea rcx, [rel ex_other]
    call print_z
    jmp .end

.managed:
    cmp word [rel class_buf], 'N'
    jne .ports
    cmp word [rel class_buf+2], 'e'
    jne .ports
    cmp word [rel class_buf+4], 't'
    jne .ports
    lea rcx, [rel ex_net]
    call print_z
    jmp .end

.ports:
    cmp word [rel class_buf], 'P'
    jne .usb
    cmp word [rel class_buf+2], 'o'
    jne .usb
    cmp word [rel class_buf+4], 'r'
    jne .usb
    lea rcx, [rel ex_ports]
    call print_z
    jmp .end

.usb:
    cmp word [rel class_buf], 'U'
    jne .hid
    cmp word [rel class_buf+2], 'S'
    jne .hid
    cmp word [rel class_buf+4], 'B'
    jne .hid
    lea rcx, [rel ex_usb]
    call print_z
    jmp .end

.hid:
    cmp word [rel class_buf], 'H'
    jne .media
    cmp word [rel class_buf+2], 'I'
    jne .media
    cmp word [rel class_buf+4], 'D'
    jne .media
    lea rcx, [rel ex_hid]
    call print_z
    jmp .end

.media:
    cmp word [rel class_buf], 'M'
    jne .image
    cmp word [rel class_buf+2], 'E'
    jne .image
    cmp word [rel class_buf+4], 'D'
    jne .image
    lea rcx, [rel ex_media]
    call print_z
    jmp .end

.image:
    cmp word [rel class_buf], 'I'
    jne .bluetooth
    cmp word [rel class_buf+2], 'm'
    jne .bluetooth
    cmp word [rel class_buf+4], 'a'
    jne .bluetooth
    lea rcx, [rel ex_image]
    call print_z
    jmp .end

.bluetooth:
    cmp word [rel class_buf], 'B'
    jne .storage
    cmp word [rel class_buf+2], 'l'
    jne .storage
    cmp word [rel class_buf+4], 'u'
    jne .storage
    lea rcx, [rel ex_bt]
    call print_z
    jmp .end

.storage:
    cmp word [rel class_buf], 'D'
    jne .portable
    cmp word [rel class_buf+2], 'i'
    jne .portable
    cmp word [rel class_buf+4], 's'
    jne .portable
    lea rcx, [rel ex_storage]
    call print_z
    jmp .end

.portable:
    cmp word [rel class_buf], 'W'
    jne .input
    cmp word [rel class_buf+2], 'P'
    jne .input
    cmp word [rel class_buf+4], 'D'
    jne .input
    lea rcx, [rel ex_portable]
    call print_z
    jmp .end

.input:
    cmp word [rel class_buf], 'K'
    je .input_text
    cmp word [rel class_buf], 'H'
    je .input_text
    cmp word [rel class_buf], 'M'
    jne .monitor
    cmp word [rel class_buf+2], 'o'
    jne .generic
    cmp word [rel class_buf+4], 'u'
    je .input_text
    jmp .generic

.input_text:
    lea rcx, [rel ex_input]
    call print_z
    jmp .end

.monitor:
    cmp word [rel class_buf], 'M'
    jne .biometric
    cmp word [rel class_buf+2], 'o'
    jne .generic
    cmp word [rel class_buf+4], 'n'
    jne .generic
    lea rcx, [rel ex_monitor]
    call print_z
    jmp .end

.biometric:
    cmp word [rel class_buf], 'B'
    jne .generic
    cmp word [rel class_buf+2], 'i'
    jne .generic
    cmp word [rel class_buf+4], 'o'
    jne .generic
    lea rcx, [rel ex_biometric]
    call print_z
    jmp .end

.generic:
    lea rcx, [rel ex_generic]
    call print_z

.end:
    lea rcx, [rel newline]
    call print_z

    add rsp, 40
    ret

; Print all information about the current device.
print_device:
    sub rsp, 40

    lea rcx, [rel device_title]
    call print_z

    lea rcx, [rel name_label]
    mov edx, 12                 ; SPDRP_FRIENDLYNAME
    call print_property

    lea rcx, [rel desc_label]
    xor edx, edx                ; SPDRP_DEVICEDESC
    call print_property

    lea rcx, [rel mfg_label]
    mov edx, 11                 ; SPDRP_MFG
    call print_property

    lea rcx, [rel class_label]
    mov edx, 7                  ; SPDRP_CLASS
    call print_property

    lea rcx, [rel hw_label]
    mov edx, 1                  ; SPDRP_HARDWAREID
    call print_property

    call print_instance
    call print_explanation

    lea rcx, [rel newline]
    call print_z

    add rsp, 40
    ret

; Enumerate the device list for the selected section.
enumerate_pass:
    sub rsp, 40
    mov dword [rel g_index], 0

.next:
    mov dword [rel g_devinfo], 32

    mov rcx, [rel g_devset]
    mov edx, [rel g_index]
    lea r8, [rel g_devinfo]
    call SetupDiEnumDeviceInfo

    test eax, eax
    jz .finished

    ; Retrieve the class name.
    mov rcx, [rel g_devset]
    lea rdx, [rel g_devinfo]
    mov r8d, 7                  ; SPDRP_CLASS
    call get_property

    test eax, eax
    jz .skip

    call copy_class
    call is_managed

    ; Pass 0: manageable classes; pass 1: all remaining classes.
    mov edx, 1
    sub edx, [rel g_pass]
    cmp eax, edx
    jne .skip

    call print_device

.skip:
    inc dword [rel g_index]
    jmp .next

.finished:
    add rsp, 40
    ret

main:
    and rsp, -16
    sub rsp, 128

    lea rcx, [rel title]
    call print_z

    ; DIGCF_PRESENT | DIGCF_ALLCLASSES = 0x6
    xor ecx, ecx
    xor edx, edx
    xor r8d, r8d
    mov r9d, 6
    call SetupDiGetClassDevsW

    cmp rax, -1
    je .error

    mov [rel g_devset], rax

    ; First pass: potentially manageable devices.
    mov dword [rel g_pass], 0
    lea rcx, [rel section1]
    call print_z
    call enumerate_pass

    ; Second pass: all remaining devices.
    mov dword [rel g_pass], 1
    lea rcx, [rel section2]
    call print_z
    call enumerate_pass

    mov rcx, [rel g_devset]
    call SetupDiDestroyDeviceInfoList

    lea rcx, [rel done_text]
    call print_z

    ; Wait for Enter so the program does not exit immediately.
    mov ecx, -10                ; STD_INPUT_HANDLE
    call GetStdHandle

    mov rcx, rax
    lea rdx, [rel input_buf]
    mov r8d, 2
    lea r9, [rel chars_read]
    mov qword [rsp+32], 0
    call ReadConsoleW

    xor ecx, ecx
    call ExitProcess

.error:
    lea rcx, [rel error_text]
    call print_z
    xor ecx, ecx
    call ExitProcess
