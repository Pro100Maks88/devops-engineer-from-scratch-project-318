# Доска объявлений (Observability)

[![hexlet-check](https://github.com/Pro100Maks88/devops-engineer-from-scratch-project-318/actions/workflows/hexlet-check.yml/badge.svg)](https://github.com/Pro100Maks88/devops-engineer-from-scratch-project-318/actions)

Автоматизация раскатывания контейнеризированного приложения на сервер в облаке.

Учебный проект Хекслета: https://ru.hexlet.io/programs/devops-engineer-from-scratch
Как это должно работать: https://asciinema.org/a/v4evn7XjCdou7Yh71IG0ljb0W

## Стек

- **Java / Spring Boot** — приложение «доска объявлений» (REST API)
- **Docker** — контейнеризация приложения
- **Ansible** — автоматизация настройки и деплоя
- **Nginx** — обратный прокси, Basic-аутентификация, JSON-логи
- **Make** — интерфейс для запуска задач
- **Yandex Cloud** — инфраструктура (ВМ, Managed PostgreSQL, Object Storage)

## Инфраструктура

| Компонент | Адрес / Данные |
| :--- | :--- |
| Сервер (ВМ Yandex Cloud) | `130.193.58.173` |
| Приложение (API, Swagger UI) | `http://130.193.58.173:8080` |
| Health-check (через Nginx, Basic Auth) | `http://130.193.58.173/actuator/health` |
| Метрики Prometheus (через Nginx, Basic Auth) | `http://130.193.58.173/actuator/prometheus` |
| PostgreSQL | `rc1d-fnumjpmf6ujptcks.mdb.yandexcloud.net:6432`, база `bulletin` |
| Object Storage | бакет `bulletin-storage` |

## Обратный прокси и защита эндпоинтов

Эндпоинты Actuator (`/actuator/health`, `/actuator/prometheus`) закрыты от прямого
доступа: приложение слушает management-порт `9090` только на `127.0.0.1`, наружу он
недоступен. Доступ организован через **Nginx** (порт 80) с Basic-аутентификацией
(`auth_basic`), логин и пароль задаются в `ansible/.env` и разворачиваются в
`.htpasswd` во время деплоя.

Доступ к метрикам и health-check снаружи:

```bash
set -a && . ./ansible/.env && set +a

curl -s -u "${METRICS_USER}:${METRICS_PASSWORD}" http://130.193.58.173/actuator/health
# Ожидается: {"groups":["liveness","readiness"],"status":"UP"}

curl -s -u "${METRICS_USER}:${METRICS_PASSWORD}" http://130.193.58.173/actuator/prometheus
# Ожидается: текст в формате Prometheus exposition (# HELP ... # TYPE ...)
```
Все обращения к защищённым эндпоинтам логируются Nginx в JSON-формате (/var/log/nginx/metrics_access.log): время, IP, статус, upstream и время ответа. Это удобно для разбора инцидентов и для будущего сбора логов.

Пример записи в логе:

```bash
{"time":"2026-11-25T13:36:20+00:00","remote_addr":"37.128.243.198","request":"GET /actuator/prometheus HTTP/1.1","status":200,"body_bytes_sent":21632,"upstream_addr":"127.0.0.1:9090","upstream_response_time":"0.054","http_user_agent":"curl/8.9.1"}
```
## Метрики для Prometheus

Метрики поступают из двух источников:
- **Spring Boot Actuator** (Micrometer) — эндпоинт `/actuator/prometheus` за Nginx с Basic-аутентификацией;
- **node_exporter** — системные метрики ВМ (роль `node_exporter` в Ansible).

### Метрики приложения (Spring Boot / Micrometer)

| Метрика | Тип | Описание | Зачем отслеживать |
| :--- | :--- | :--- | :--- |
| `process_uptime_seconds` | Gauge | Время работы процесса с момента старта | Детект рестартов и крашей: сброс значения — признак перезапуска сервиса |
| `http_server_requests_seconds_count` | Counter | Количество HTTP-запросов (с тегами `uri`, `method`, `status`) | Базовый трафик-метрик; рост 5xx — сигнал о деградации |
| `http_server_requests_seconds_sum` | Counter | Суммарное время ответов на HTTP-запросы | Вместе с `_count` даёт среднюю latency: `_sum / _count` |
| `http_server_requests_seconds_max` | Gauge | Максимальное время ответа за окно | Хвосты задержек (p-max), которые прячутся за средней |
| `system_cpu_usage` | Gauge | Загрузка CPU системы (0–1) | Детект нехватки ресурсов под нагрузкой |
| `process_cpu_usage` | Gauge | Загрузка CPU процессом приложения | Отделить «виновника» тормозов: JVM или соседние процессы |
| `jvm_memory_used_bytes` | Gauge | Использованная память JVM по пулам (тег `area`) | Рост к пределу кучи — риск GC-пауз и OOM |
| `jvm_gc_pause_seconds_sum` | Counter | Суммарное время GC-пауз | Частые/долгие паузы = деградация отзывчивости |
| `hikaricp_connections_active` | Gauge | Активные соединения с БД (пул HikariCP) | Исчерпание пула соединений при росте нагрузки |
| `bulletins_created_total` *(пример кастомной)* | Counter | Число созданных объявлений | Бизнес-метрика: следить за активностью пользователей |

### Метрики хоста (node_exporter)

| Метрика | Тип | Описание | Зачем отслеживать |
| :--- | :--- | :--- | :--- |
| `node_load1` | Gauge | Средняя нагрузка (load average) за 1 минуту | Быстрая реакция на пик нагрузки; сравнивать с числом ядер |
| `node_cpu_seconds_total` | Counter | Время CPU по режимам (тег `mode`: user, system, iowait...) | Высокий `iowait` — узкое место в диске |
| `node_memory_MemAvailable_bytes` | Gauge | Доступная память | Алерт при падении ниже порога — риск OOM-killer |
| `node_filesystem_avail_bytes` | Gauge | Свободное место на ФС (тег `mountpoint`) | Заполненный диск = остановка приложения и БД |
| `node_network_receive_bytes_total` | Counter | Принятые байты по сетевым интерфейсам | Аномальный трафик и его распределение по интерфейсам |

### Порядок сбора

1. node_exporter слушает `9100` на `127.0.0.1`.
2. Prometheus (на этом же сервере или внешнем) скрейпит:
   - `http://<host>/actuator/prometheus` — через Nginx с Basic-аутентификацией;
   - `http://<host>:9100/metrics` — через reverse-proxy по аналогичной схеме.
3. Retention и правила алертов настраиваются в `prometheus.yml` на следующем этапе.


## Где лежат плейбуки
Плейбуки Ansible расположены в директории `ansible/`:

- `ansible/deploy.yml` — основной плейбук для подготовки сервера и деплоя приложения;
- `ansible/inventory.ini` — инвентарь (список хостов) для Ansible;
- `ansible/.env` — переменные окружения (секреты), не попадают в репозиторий (см. `.gitignore`).

## Установка
```bash
git clone https://github.com/Pro100Maks88/devops-engineer-from-scratch-project-318.git
cd devops-engineer-from-scratch-project-318
```
Перед запуском необходимо подготовить файл с секретами:
```bash
cp ansible/.env.example ansible/.env
```
(Если файла .env.example нет, создайте ansible/.env вручную и пропишите в нём переменные согласно документации проекта.)

Заполните ansible/.env данными вашего окружения (IP, пользователь, пароли).

## Команды запуска

Все операции выполняются через Makefile в корне проекта:
```bash
make deploy    # Запуск плейбука ansible/deploy.yml: подготовка сервера и раскатка приложения
make status    # Проверка состояния контейнера на сервере (аналог docker ps)
make logs      # Просмотр логов приложения
make health    # Проверка работоспособности сервиса (curl к /actuator/health)
make metrics   # Проверка экспорта метрик Prometheus (curl к /actuator/prometheus)
```
## Примеры проверки работы
После выполнения make deploy проверьте доступность сервиса:

```bash
curl http://130.193.58.173:8080/api/bulletins
# Ожидается список объявлений (JSON)

curl http://130.193.58.173:8080/swagger-ui/index.html
# Ожидается страница Swagger UI
```

Swagger UI доступен по адресу: http://130.193.58.173:8080/swagger-ui/index.html

## О Хекслете

[Хекслет](https://ru.hexlet.io/) — школа программирования: авторские программы обучения с практикой, поддержкой наставников и реальными проектами, которые остаются в резюме. Этот репозиторий — один из таких проектов.