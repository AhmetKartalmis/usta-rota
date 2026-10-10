# Derleme: Dart kodunu tek bir yerel çalıştırılabilir dosyaya çevirir.
FROM dart:stable AS build
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get
COPY . .
RUN dart pub get --offline && dart compile exe bin/server.dart -o bin/server

# Çalışma: yalnızca derlenmiş dosya + statik sayfa. Kaynak kod ve SDK imajda yok.
FROM scratch
COPY --from=build /runtime/ /
# Postgres'e TLS ile bağlanmak için kök sertifikalar.
COPY --from=build /etc/ssl/certs /etc/ssl/certs
COPY --from=build /app/bin/server /app/bin/server
COPY --from=build /app/public /app/public
WORKDIR /app
EXPOSE 8080
CMD ["/app/bin/server"]
