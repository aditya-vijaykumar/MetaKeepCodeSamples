package xyz.metakeep.metakeepcodesample

import android.os.Bundle
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import org.json.JSONArray
import org.json.JSONObject

class NftListActivity : AppCompatActivity() {

    private lateinit var newRecyclerview: RecyclerView
    private lateinit var newArrayList: ArrayList<Nft>

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_nft_list)

        newRecyclerview = findViewById((R.id.result_recyle_view))
        newRecyclerview.layoutManager = LinearLayoutManager(this)

        newArrayList = arrayListOf<Nft>()
        val result = intent.getStringExtra("result")
        if (JSONArray(result).length() == 0) {
            Toast.makeText(this, "No NFTs Found", Toast.LENGTH_SHORT).show()
            finish()
        } else {
            getUserData(JSONArray(result))
        }
    }

    private fun getUserData(result: JSONArray) {
        for (i in 0 until result.length()) {
            val nft = result[i] as JSONObject
            val token = Nft(nft.getString("collection"), nft.getString("token"), nft.getJSONObject("tokenMetadata"), intent.getStringExtra("nftOwner").toString())
            newArrayList.add(token)
        }

        newRecyclerview.adapter = NftViewAdapter(newArrayList)
    }
}
