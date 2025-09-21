import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.io.StringReader;
import org.postgresql.copy.CopyManager;
import org.postgresql.core.BaseConnection;
import com.github.javafaker.Faker;

public class InsertDataFaker {
    public static void main(String[] args) {
        String url = "jdbc:postgresql://localhost:5432/hotel_db"; // ajuste o banco
        String user = "postgres";       // seu usuário
        String password = "1234";  // sua senha

        int totalRegistros = 2_000_000; // quantidade de registros
        int bloco = 50_000;             // envia a cada 50 mil registros

        long start = System.currentTimeMillis();

        Faker faker = new Faker();      // gerador de dados realistas

        try (Connection conn = DriverManager.getConnection(url, user, password)) {
            // 🔹 Limpa a tabela antes de inserir
            conn.createStatement().executeUpdate("TRUNCATE TABLE Customers RESTART IDENTITY CASCADE");

            CopyManager copyManager = new CopyManager((BaseConnection) conn);
            StringBuilder sb = new StringBuilder();

            for (int i = 1; i <= totalRegistros; i++) {
                String nome = faker.name().fullName();
                String email = faker.internet().emailAddress();
                String telefone = faker.phoneNumber().cellPhone();

                sb.append(nome).append("\t")
                        .append(email).append("\t")
                        .append(telefone).append("\n");

                // envia em blocos
                if (i % bloco == 0) {
                    copyManager.copyIn("COPY Customers(full_name,email,phone) FROM STDIN WITH DELIMITER E'\\t'", new StringReader(sb.toString()));
                    sb.setLength(0);
                    System.out.println(i + " registros inseridos...");
                }
            }

            // envia os registros restantes
            if (sb.length() > 0) {
                copyManager.copyIn("COPY Customers(full_name,email,phone) FROM STDIN WITH DELIMITER E'\\t'", new StringReader(sb.toString()));
            }

            long end = System.currentTimeMillis();
            System.out.println("✅ Inserção concluída!");
            System.out.println("⏱ Tempo total: " + (end - start) / 1000.0 + " segundos.");

        } catch (SQLException | java.io.IOException e) {
            e.printStackTrace();
        }
    }
}
