//
//  DeleteAccountView.swift
//  ReportChat
//  
//  Created by SATTSAT on 2024/11/19
//  
//

import SwiftUI

struct DeleteAccountView: View {
    
    @State private var password = ""
    @FocusState private var isKeyboardFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("アカウントを削除します")
                .font(.title.bold())
                .foregroundStyle(.red)
            
            Text(
                """
                アカウントを削除すると、ルーム内メッセージの確認、メッセージの送信、友達との会話は見れなくなってしまいます。
                """
            )
            .foregroundStyle(.secondary)
            
            Divider()
            
            InputFormView(
                secureType: .secure,
                keyboardType: .alphabet,
                title: "アカウントを削除するには、\nパスワードを入力してください。",
                placeholder: "パスワード",
                text: $password
            )
            .focused($isKeyboardFocused)
            
            CapsuleButton(
                icon: .delete,
                style: password.isEmpty ? .disable : .denger,
                text: "削除",
                onClicked: {
                    isKeyboardFocused = false
                    self.deleteUser()
                }
            )
            
            Spacer()
        }
        .padding()
        .background(.mainBackground)
    }
    
    func deleteUser() {
        UIApplication.showLoading(message: "データを削除中です...")
        
        Task {
            let deleteResult = await UserServiceManager.shared
                .deleteUser(password: password)
            
            switch deleteResult {
            case .success(_):
                UIApplication.showToast(
                    type: .info,
                    message: "アカウント削除に成功しました")
            case .failure(let error):
                FirebaseError.shared.showErrorToast(error)
            }
            
            UIApplication.hideLoading()
        }
    }
}

#Preview {
    DeleteAccountView()
}
